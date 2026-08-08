#!/usr/bin/env node
// geocode.js — fills in lat/lon for every place that doesn't have one,
// via OpenStreetMap Nominatim (1 req/sec, cached in data/geo.json).
// overrides.json lls always win; this only covers the gaps.
// Statewide road-trip entries are skipped — they're routes, not points.

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const seed = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets', 'seed.json'), 'utf8'));
const geoPath = path.join(ROOT, 'data', 'geo.json');
const geo = fs.existsSync(geoPath) ? JSON.parse(fs.readFileSync(geoPath, 'utf8')) : {};

const SKIP_REGIONS = new Set(['statewide-experiences-and-road-trips']);
const sleep = ms => new Promise(r => setTimeout(r, ms));

function inBounds(lat, lon) {
  // California + Nevada border towns + Arizona leg
  return lat >= 31.0 && lat <= 42.5 && lon >= -125.0 && lon <= -108.9;
}

async function lookup(q) {
  const url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=' +
    encodeURIComponent(q);
  const res = await fetch(url, {
    headers: { 'User-Agent': 'poppy-trip-planner/1.0 (personal app)' },
  });
  if (!res.ok) return null;
  const arr = await res.json();
  if (!arr.length) return null;
  const lat = parseFloat(arr[0].lat), lon = parseFloat(arr[0].lon);
  if (!inBounds(lat, lon)) return null;
  return [Math.round(lat * 1000) / 1000, Math.round(lon * 1000) / 1000];
}

(async () => {
  const misses = [];
  let queried = 0, found = 0;
  for (const p of seed.places) {
    if (p.ll || geo[p.id] || SKIP_REGIONS.has(p.region)) continue;
    const outOfState = p.region === 'out-of-state';
    const state = outOfState ? 'Arizona, USA' : 'California, USA';
    // Strip parenthetical hints out of names; try most-specific first.
    const cleanName = p.name.replace(/\(.+?\)/g, '').trim();
    const attempts = [
      p.loc ? `${cleanName}, ${p.loc}, ${state}` : null,
      `${cleanName}, ${state}`,
      p.loc ? `${p.loc}, ${state}` : null, // city-level fallback
    ].filter(Boolean);
    let hit = null;
    for (const q of attempts) {
      queried++;
      try {
        hit = await lookup(q);
      } catch (_) { hit = null; }
      await sleep(1100);
      if (hit) break;
    }
    if (hit) {
      geo[p.id] = hit;
      found++;
      console.log(`ok  ${p.id} -> ${hit}`);
    } else {
      misses.push(p.id);
      console.log(`MISS ${p.id}`);
    }
    // save as we go so an interrupt loses nothing
    if (found % 10 === 0) {
      fs.writeFileSync(geoPath, JSON.stringify(geo, null, 1));
    }
  }
  fs.writeFileSync(geoPath, JSON.stringify(geo, null, 1));
  console.log(`\nqueried ${queried}, found ${found}, cached ${Object.keys(geo).length}`);
  if (misses.length) console.log(`misses (${misses.length}): ${misses.join(', ')}`);
})();
