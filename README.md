# Poppy 🌼

California trip planner, built for weekend runs out of Modesto. 443 places,
season windows, ready-made trips, a poster-art map, and a list that updates
itself.

## How it works

- **The list lives in [data/california-trip-planner.md](data/california-trip-planner.md).**
  Edit it, push, and the `Rebuild seed` action regenerates
  `assets/seed.json`. Installed apps pull the new list on next launch
  (or Settings → Refresh the place list). No APK release needed.
- **Hand-tuned data** (season windows, map pin coords, lat/lon for weather)
  lives in [data/overrides.json](data/overrides.json), keyed by place slug.
- **Your data never gets clobbered.** Done dates, hidden places, custom
  places/trips, plans, and reservations live in an overlay on the phone
  (optionally backed up to the private `poppy-data` repo). Seed updates and
  app updates leave it untouched.
- **App updates** ship as GitHub Releases. The app checks on launch and from
  Settings, downloads the APK in-app, and hands it to Android's installer.

## Building

CI does everything: push to `main` builds a signed APK artifact; pushing a
`v*` tag publishes it as a Release. The `android/` project is generated fresh
in CI (`flutter create`), so the repo tracks only `lib/`, `pubspec.yaml`,
`assets/`, `data/`, and `tools/`.

Secrets: `KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`. The keystore
itself stays offline — losing it means updates stop installing over the old
signature, so don't.

## Layout

| Path | What |
|---|---|
| `lib/` | The Flutter app (all screens + services) |
| `data/california-trip-planner.md` | **The master list — edit this** |
| `data/overrides.json` | Season windows, pins, coords per place slug |
| `tools/build_seed.js` | md → seed.json parser |
| `assets/seed.json` | Generated. Don't hand-edit |
