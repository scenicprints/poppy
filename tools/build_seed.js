#!/usr/bin/env node
// build_seed.js — parses data/california-trip-planner.md into assets/seed.json.
// The markdown doc is the source of truth; edit it, run this (or let the
// GitHub Action run it), and the app picks up the new seed on next refresh.
//
// Recognized markdown shapes (matching the doc's existing style):
//   # PART 1 ... "## 3. Region Name"            -> region
//   "- **Name** (Location) — desc *(seasonal — note)*"  -> place
//   # PART 3 ... "## Tier Heading"               -> trip tier
//   "**7. Trip Name** — Stop → Stop → Stop. *Season note*" -> trip
//
// data/overrides.json adds hand-tuned info the prose can't carry:
// per-place months/window-type, map pin coords, lat/lon, links.

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const md = fs.readFileSync(path.join(ROOT, 'data', 'california-trip-planner.md'), 'utf8');
const overrides = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'overrides.json'), 'utf8'));
const geoPath = path.join(ROOT, 'data', 'geo.json');
// Geocoded fallback coordinates (tools/geocode.js); override lls always win.
const geo = fs.existsSync(geoPath) ? JSON.parse(fs.readFileSync(geoPath, 'utf8')) : {};

const slug = s => s.toLowerCase()
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/&/g, 'and').replace(/[''`]/g, '')
  .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

// ---- split the doc into parts ----
const partIdx = [...md.matchAll(/^# PART (\d+)/gm)].map(m => ({ n: +m[1], at: m.index }));
const partText = n => {
  const i = partIdx.findIndex(p => p.n === n);
  if (i < 0) return '';
  const end = i + 1 < partIdx.length ? partIdx[i + 1].at : md.length;
  return md.slice(partIdx[i].at, end);
};

// ---- Part 1: regions & places ----
const MONTH_WORDS = {
  jan: 1, feb: 2, mar: 3, march: 3, apr: 4, april: 4, may: 5, jun: 6, june: 6,
  jul: 7, july: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12,
};
const SEASON_WORDS = {
  winter: [12, 1, 2], spring: [3, 4, 5], summer: [6, 7, 8], fall: [9, 10, 11],
};

function monthsFromText(t) {
  t = t.toLowerCase();
  for (const [w, m] of Object.entries(SEASON_WORDS)) if (t.includes(w)) {
    // "harvest season Sept–Oct" style ranges beat bare season words below
  }
  // explicit month range e.g. "Sept–Oct", "late May/June–Oct/Nov", "Dec 15–Mar 31"
  const found = [];
  const rangeRe = /([a-z]{3,9})\.?\s*\d{0,2}\s*[–\-\/]\s*(?:[a-z]{3,9}\.?\s*)?\d{0,2}/g;
  const words = [...t.matchAll(/[a-z]{3,9}/g)].map(m => m[0]).filter(w => MONTH_WORDS[w] !== undefined);
  if (words.length >= 2) {
    let a = MONTH_WORDS[words[0]], b = MONTH_WORDS[words[words.length - 1]];
    let m = a;
    for (let i = 0; i < 12; i++) { found.push(m); if (m === b) break; m = m === 12 ? 1 : m + 1; }
    return found;
  }
  if (words.length === 1) return [MONTH_WORDS[words[0]]];
  for (const [w, ms] of Object.entries(SEASON_WORDS)) if (t.includes(w)) return ms;
  return null;
}

const regions = [];
const places = [];
const usedOverrides = new Set();
{
  const text = partText(1);
  let region = null;
  for (const line of text.split('\n')) {
    const rh = line.match(/^## \d+\.\s+(.+)$/);
    if (rh) {
      region = { id: slug(rh[1]), name: rh[1].trim() };
      regions.push(region);
      continue;
    }
    const pl = line.match(/^- \*\*(.+?)\*\*\s*(?:\((.+?)\))?\s*(?:—\s*)?(.*)$/);
    if (pl && region) {
      let [, name, loc, rest] = pl;
      rest = (rest || '').trim();
      let season = null;
      const seas = rest.match(/\*\((?:seasonal\s*—\s*)?(.+?)\)\*\s*$/) || rest.match(/\*\((.+?)\)\*/);
      // seasonal notes appear as *(seasonal — X)* or *(...)* at line end
      const seasInline = (line.match(/\*\((.+?)\)\*/) || [])[1];
      if (seasInline) {
        const label = seasInline.replace(/^seasonal\s*—\s*/, '').trim();
        const months = monthsFromText(label);
        const hard = /only|closed|snowed|open roughly|typically open|dec 15/i.test(seasInline) || /^seasonal/.test(seasInline);
        season = { label, months: months || [], type: hard ? 'hard' : 'best' };
      }
      const desc = rest.replace(/\s*\*\(.+?\)\*\s*$/, '').trim();
      const id = slug(name);
      const o = overrides.places[id] || {};
      usedOverrides.add(id);
      // hand-tuned wins; season:false means "that italic note isn't a season"
      if (o.season !== undefined) season = o.season || null;
      places.push({
        id, name: name.trim(), region: region.id,
        loc: (loc || '').trim() || undefined,
        desc: desc || undefined,
        season: season || undefined,
        pin: o.pin, ll: o.ll || geo[id], links: o.links,
      });
    }
  }
}

// ---- Part 3: trips ----
const trips = [];
{
  const text = partText(3);
  let tier = null;
  for (const line of text.split('\n')) {
    const th = line.match(/^## (.+?)(?:\s*\(.*)?$/);
    if (th) { tier = th[1].trim(); continue; }
    const tm = line.match(/^\*\*(\d+)\.\s+(.+?)\*\*\s*—\s*(.+)$/);
    if (tm && tier) {
      const [, , name, rest] = tm;
      const seasonNote = (rest.match(/\*(.+?)\*\s*$/) || [])[1] || '';
      const body = rest.replace(/\s*\*.+?\*\s*$/, '').trim();
      const stops = body.split('→').map(s => s.replace(/\.$/, '').trim()).filter(Boolean)
        .map(text => {
          // try to link a stop back to a place id
          const clean = slug(text.replace(/\(.+?\)/g, ''));
          const hit = places.find(p => clean.includes(p.id) || p.id.includes(clean) ||
            slug(text).includes(p.id) || p.id.includes(slug(text)));
          return hit ? { text, placeId: hit.id } : { text };
        });
      trips.push({
        id: slug(name), name: name.trim(), tier,
        stops, season: seasonNote.trim() || undefined,
      });
    }
  }
}

// ---- curated trips from data/trips.json (survive doc rewrites) ----
{
  const tj = JSON.parse(
      fs.readFileSync(path.join(ROOT, 'data', 'trips.json'), 'utf8'));
  const placeIds = new Set(places.map(p => p.id));
  for (const t of tj.trips) {
    for (const s of t.stops) {
      if (s.placeId && !placeIds.has(s.placeId)) {
        console.warn(`WARN trip "${t.name}": unknown placeId ${s.placeId}`);
        delete s.placeId;
      }
    }
    if (!trips.some(x => x.id === t.id)) trips.push(t);
  }
}

const seed = {
  version: Date.now(),
  generatedFrom: 'california-trip-planner.md',
  regions, places, trips,
};

fs.writeFileSync(path.join(ROOT, 'assets', 'seed.json'), JSON.stringify(seed, null, 1));

// ---- report ----
const seasonal = places.filter(p => p.season).length;
const pinned = places.filter(p => p.ll).length;
console.log(`regions: ${regions.length}`);
for (const r of regions) console.log(`  ${r.name}: ${places.filter(p => p.region === r.id).length}`);
console.log(`places: ${places.length} (${seasonal} seasonal, ${pinned} with coordinates)`);
console.log(`trips: ${trips.length}`);
const unlinked = trips.flatMap(t => t.stops.filter(s => !s.placeId).map(s => `${t.name} :: ${s.text}`));
console.log(`trip stops not linked to a place: ${unlinked.length}`);
const dead = Object.keys(overrides.places).filter(k => !usedOverrides.has(k));
if (dead.length) console.warn(`WARN dead override keys (no matching place): ${dead.join(', ')}`);
