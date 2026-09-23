# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Keep the Pace** — a single-screen mobile web app for walking to a destination by a target time. The user picks a destination and an "arrive by" time; during the walk it shows how many seconds ahead of or behind schedule they are, plus remaining distance, heading and speed. It has a demo mode that simulates a walk with no GPS.

The project was exported from Grok App Builder (TanStack Start template). `AGENTS.md` is that platform's sandbox contract (written for a Linux sandbox at `/workspace` with a live preview on `0.0.0.0:8080`). Much of it does not apply when working locally. What still applies: don't edit or delete platform files (`public/__grok/`, `server/`, `scripts/grok-pwa-*`, `src/lib/auth`, `src/lib/app-data`, `<PreviewHostBridge />` in `__root.tsx`), don't put `og:*` tags in `__root.tsx`, and don't create a `.env`.

## Commands

`node_modules/` is not checked in, so run `npm install` first.

```bash
npm run dev          # vite dev on 0.0.0.0:8080, run via scripts/with-app-env.mjs
npm run build        # vite build + scripts/migrate.mjs (skips when DATABASE_URL is unset)
npm run typecheck    # tsc --noEmit
npm run lint         # eslint .
npm run format       # prettier --write . (100 cols, double quotes, trailing commas)
npm test             # node:test over scripts/**/*.test.mjs + a few src/lib/{auth,app-data} tests
```

Run a single test file:

```bash
node --test scripts/preview.test.mjs
node --experimental-strip-types --test src/lib/auth/sign-in-gate.test.ts
```

Always start Vite through the npm scripts, never `vite` directly: `scripts/with-app-env.mjs` injects `.grok/app-env.json` (`VITE_AUTH_ENABLED`) into the environment. The existing tests cover only template/platform code. The app logic in `src/lib/{geo,pace,format}.ts` has no tests.

Sandbox-only pieces: `startup.sh` hard-codes `cd /workspace`, and `scripts/preview.mjs` (`preview:restart` / `preview:stop`, which serves the build on :8081) reads `/proc`, so it only works on Linux.

## Architecture

TanStack Start + React 19 + Tailwind v4. There is one route (`src/routes/index.tsx`). Auth and the DB are **off** (`.grok/app-env.json`: `VITE_AUTH_ENABLED: "false"`, `database: false`). There are no top-level migrations, and the app code does not import `@/lib/db`. The only persistence is `localStorage` (`ktp:units`, `ktp:recent`).

**State lives in one hook.** `src/hooks/use-pace-app.ts` holds the phase machine (`setup` → `walk` → `arrived`) and all session state. `index.tsx` renders `SetupView` or `WalkView` from its return value. Both components are presentational and take props only, except `SetupView`, which runs its own destination search.

**Pace math** (`src/lib/geo.ts`, `src/lib/pace.ts`):
- A `Session` fixes `startDistanceM`, `startAt` and `arriveBy` when the walk starts. `scheduleDeltaSec` compares the distance you have actually covered with the distance a constant pace would have covered by now, then turns the gap into seconds (positive = early).
- Arrival is always judged by straight-line distance ≤ `ARRIVE_RADIUS_M` (18 m). When that happens, the delta is frozen in a ref.
- If the plan came from street routing (`session.routed`), the remaining distance is re-fetched from OSRM every 12 s during the walk. If routing fails, it falls back to straight-line distance.

**External services** (browser `fetch`, no API keys, and every call fails soft):
- `src/lib/route.ts`: public OSRM foot router (`router.project-osrm.org`) with a 4 s timeout. Returns `null` on failure.
- `src/lib/geocode.ts`: search merges the local gazetteer (`src/data/places.ts`, mostly NYC plus a few world landmarks) with Open-Meteo geocoding (2.5 s timeout). Results are ranked by name match, a bonus for gazetteer hits, and distance from the user. Raw `lat, lon` input is parsed directly.

**Setup planning:** choosing a destination first sets `arriveBy` from the straight-line distance at 1.34 m/s, rounded up to the minute. It then upgrades asynchronously to the OSRM distance, unless the user has already edited the time (`etaTouched`) or picked a different destination (`planToken`).

**Browser APIs:** `use-geolocation.ts` uses `watchPosition` with high accuracy. If the device reports no speed, it derives speed from consecutive fixes and smooths it. `use-wake-lock.ts` holds a screen wake lock during `walk` and re-acquires it when the tab becomes visible again. Demo mode stops GPS and moves a fake fix toward the destination every 250 ms, starting 280 m away.

**Styling:** design tokens live in `src/styles.css` under `@theme`, e.g. `--color-early`, `--color-late`, `--color-ontime` and `--tracking-label`. Use those tokens rather than raw colors. The `@/` import alias maps to `src/`.

## iOS / watchOS app (`ios/`)

The native iPhone and Apple Watch app is being built in `ios/`. The design is in `docs/superpowers/specs/2026-09-22-ios-watch-app-design.md`. The web app in `src/` is the **reference implementation** for the pace math and formatting; it is not shipped.

- **The project is generated.** `ios/project.yml` (XcodeGen) is the source of truth. `KeepThePace.xcodeproj`, the `Info.plist` files and the `.entitlements` files are generated and gitignored. Change targets, capabilities, Info keys and build settings in `project.yml`, never in Xcode's settings panes; those edits are lost at the next generate.
- **Targets:** `KeepThePace` (iOS app), `PaceActivity` (Live Activity extension), `KeepThePaceWatch` (watchOS app, embedded in the iOS app) and `PaceComplication` (watch widget extension). All four depend on the local package `ios/PaceKit`.
- **Bundle IDs:** the prefix is `com.iliasrafailidis.delta`, the App Group is `group.com.iliasrafailidis.delta` and the team is `3DLV25C9VK`. The bundle ID cannot change once registered; the display name can.
- **PaceKit** is pure Swift with no UI or Core Location, so all app logic that can be tested lives there. Its formatters use `JSNumber` (`Math.round` and `toFixed` semantics) so the output matches the web app character for character. Don't replace these with `String(format:)`: it rounds ties differently.
- **Golden vectors:** `ios/PaceKit/Scripts/make-golden.mjs` runs the web TypeScript (`src/lib/geo.ts`, `src/lib/format.ts`) and writes `Tests/PaceKitTests/Fixtures/golden.json`. The Swift tests must match it. Regenerate only if the web reference changes intentionally.

Commands (run from `ios/`):

```bash
make generate      # regenerate KeepThePace.xcodeproj after editing project.yml or adding files
make test          # PaceKit unit tests (swift test), no simulator needed
make golden        # regenerate golden.json from the web TypeScript
make build-ios     # generate + build the iOS app (with embedded watch app) for the simulator
make build-watch   # generate + build the watch app for the simulator
```

To run a single test: `cd ios/PaceKit && swift test --filter FormatTests` (a suite) or `--filter FormatTests/deltaMatchesWeb` (one test). Simulator builds pass `CODE_SIGNING_ALLOWED=NO`. On-device runs use Xcode with automatic signing.
