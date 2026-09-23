# Keep the Pace — native iPhone + Apple Watch app

**Date:** 2026-09-22
**Status:** Approved. Amended 2026-09-23: pace colour rule, plus three web behaviours that were missing (start rules, the arrival result, stale-fix filter).

## Goal

Ship Keep the Pace as a native iPhone app, with an Apple Watch app that gives the best experience. You set a destination and an arrive-by time. While you walk, the app tells you how many seconds ahead of or behind schedule you are: on screen, on the lock screen, and through haptics on your wrist, without you having to look.

Android is out of scope. The existing web app (`src/`) stays in the repo untouched. It serves as the **reference implementation** for the pace math, formatting and demo behaviour, not as shipped code.

## Decisions

| Topic | Decision |
|---|---|
| Stack | Native Swift and SwiftUI. No Capacitor or web view. |
| Location in repo | `ios/` folder in this repo |
| Project generation | XcodeGen: `ios/project.yml` is the source of truth, and the `.xcodeproj` is generated and gitignored |
| Minimum OS | iOS 17, watchOS 10 (needed for workout mirroring) |
| Team ID | `3DLV25C9VK` |
| Bundle IDs | `com.iliasrafailidis.delta` (app), `…delta.PaceActivity` (Live Activity extension), `…delta.watchkitapp` (Watch app), `…delta.watchkitapp.PaceComplication` (Watch widget extension) |
| App Group | `group.com.iliasrafailidis.delta` (settings and favorites shared with extensions) |
| Search and routing | Apple MapKit (`MKLocalSearchCompleter`, `MKLocalSearch`, `MKDirections` walking) |
| Map UI | None. Numbers-first screens only. |
| Pocket feedback (iPhone) | Live Activity (lock screen and Dynamic Island). The alert-flagged update fires **only when the status changes**. |
| Watch feedback | Custom haptic patterns from a background workout session |
| Health | Walks are saved to Apple Health as outdoor walking workouts with a route, from whichever device ran the walk |
| Extras in v1 | Favorites (usable from iPhone and Watch) and a Settings screen. No walk history screen, voice, or pause. |

## 1. Structure

```
ios/
  project.yml
  PaceKit/                 local Swift package (pure logic, no UIKit/SwiftUI/CoreLocation)
    Sources/PaceKit/
    Tests/PaceKitTests/
  KeepThePace/             iOS app target
  PaceActivity/            iOS widget extension (Live Activity + Dynamic Island)
  KeepThePaceWatch/        watchOS app target
  PaceComplication/        watchOS widget extension (complication / Smart Stack)
  Shared/                  code compiled into multiple targets (models, HealthService, stores)
  GPX/                     simulated walks for simulator testing
```

### PaceKit (shared, pure)
This package is ported from `src/lib/geo.ts`, `src/lib/pace.ts` and `src/lib/format.ts`:
- Geodesy functions: `haversine`, `bearing`, `destinationPoint`, `moveTowards` and `cardinal`.
- `Session` with `dest`, `start`, `startDistanceM`, `startAt`, `arriveBy`, `demo` and `routed`.
- The pace calculation: `scheduleDeltaSec` works out the distance you've actually covered minus the distance a constant pace would have covered by now, then converts that into seconds. Positive means early.
- Arrival: `ARRIVE_RADIUS_M = 18`, measured as straight-line distance. The arrival result is the delta worked out with 0 m remaining, which equals arrive-by minus the actual arrival time.
- Session start rules, as in the web's `beginSession`: the start distance is at least 30 m, and arrive-by is at least now + 60 s.
- The walk estimate at 1.34 m/s, rounded up to the minute.
- `PaceStatusMachine`, which maps the delta to one of `ahead`, `onTime` or `behind`. It uses a configurable threshold (default 30 s) and a 5 s recovery margin, so the status must come back inside the band by 5 s before it flips back. It emits a `transition` event only when the status changes.
- Formatting for distance, speed, clock time, duration, the ±m:ss delta and heading, in imperial or metric units. This matches the web output, including the "on time" rule for |delta| < 3 s.

### iOS app (`KeepThePace`)
- `WalkSession` (`@Observable`): the phase machine (`setup → walk → arrived`), the active session, the latest metrics and which device is tracking (`.phone` or `.watch`).
- `LocationService`: `CLLocationManager` with background location updates and the "When In Use" permission. The blue location indicator is on during walks. Fixes with horizontal accuracy worse than 50 m are ignored. So are fixes more than 1 s old when they arrive, matching the web's `maximumAge: 1000`, so a cached position never becomes a walk's start point (tune the 1 s after the M3 device walk if it drops real fixes). Speed comes from `CLLocation.speed`, with a fallback worked out from consecutive fixes, smoothed as in the web version with the east-west correction applied correctly (see Known web bug).
- `DemoLocationSource`: the same interface as `LocationService`. It starts 280 m from the destination at a bearing of 188° and moves 1.72 ± 0.18 m/s, ticking every 250 ms, as in `use-pace-app.ts`. The default demo destination is Gantry Plaza State Park.
- `PlaceSearchService`: type-ahead from `MKLocalSearchCompleter`, resolved with `MKLocalSearch`, biased to the user's region. Typed coordinates in `lat, lon` form are parsed directly.
- `RouteService`: `MKDirections` with `.walking`. It returns the distance in metres, or nil if unavailable, in which case the app uses straight-line distance.
- `LiveActivityController`: ActivityKit start, update and end.
- `FeedbackController`: custom haptics while the app is in the foreground. It is a no-op in the background, where the Live Activity alert takes over.
- `WatchBridge`: works out whether a paired Watch with the app installed is available, launches the Watch walk through `HKHealthStore.startWatchApp(with:)`, and receives the mirrored workout session and its state.
- `Stores` (App Group UserDefaults, Codable): `favorites` (ordered, with an optional custom label), `recents` (last 6, de-duplicated), `settings`, and `activeSession`, which is saved so a walk can be resumed after a force-quit.

### Live Activity extension (`PaceActivity`)
- `ActivityAttributes` holds the destination name and arrive-by time. `ContentState` holds `deltaSec`, `status`, `remainingM`, `units`, `arrived` and `trackingDevice`.
- Lock screen: destination, ±m:ss in the pace colour, distance left and arrive-by time.
- Dynamic Island compact view: ±m:ss on the leading side and distance on the trailing side. The expanded view has the full layout.

### Watch app (`KeepThePaceWatch`)
- `WatchWalkSession`: `HKWorkoutSession` (outdoor walking) with an `HKLiveWorkoutBuilder` and an `HKWorkoutRouteBuilder`. It uses the Watch's own Core Location, with the same accuracy and stale-fix filters as the iPhone, and the PaceKit engine, and mirrors to the iPhone with `startMirroringToCompanionDevice`.
- `WatchFeedback`: plays `WKInterfaceDevice.current().play(_:)` patterns. `.directionDown` means you've fallen behind, `.directionUp` means you're ahead, and `.success` means you're back on time. The final choice will be made on a real device.
- Favorites are synced from the phone through `WatchConnectivity` application context.

### Watch widget extension (`PaceComplication`)
Complication and Smart Stack widget: ±m:ss in the pace colour during a walk, or the app icon when idle.

## 2. How a walk runs

### Planning (iPhone)
1. Search, or tap a favorite or recent chip, then pick a destination.
2. `RouteService` fetches the walking distance. Until it returns, the straight-line distance is used. Arrive-by defaults to `roundUpToMinute(now + distance / 1.34 m/s)`. The routed distance replaces the straight-line default only if the user hasn't touched the time and hasn't changed the destination since. This mirrors `etaTouched` and `planToken`.
3. The user adjusts arrive-by with the native time picker or the −1 and +1 minute buttons. Arrive-by is always at least now + 1 minute.
4. The Start button shows "on Apple Watch" or "on iPhone", following the rule below.
5. At Start, the session's start distance is set to at least 30 m and its arrive-by to at least now + 60 s. This applies to every start: iPhone, Watch-only and demo.

### Choosing the tracking device
- The **Watch** is used if all of these hold: the setting "Prefer Apple Watch when available" is on, a Watch is paired, the Watch app is installed, and HealthKit authorization allows workouts.
- Otherwise the **iPhone** is used.

### Walk tracked on iPhone
On each accepted fix, whether the app is in the foreground or the background:
1. PaceKit computes the distance left, the heading and `deltaSec`. If the session was routed, the distance left is the latest MapKit route distance. Between route refreshes, that distance is reduced by how far you've moved since the refresh.
2. `PaceStatusMachine` updates the status. On a transition: haptic if the app is in the foreground, otherwise a Live Activity update with `AlertConfiguration`.
3. Routine Live Activity updates without an alert are sent at most every 10 s.
4. The route distance is refreshed every 60 s, or immediately if your straight-line distance to the destination has changed by more than 75 m from what the last refresh predicted.

### Walk tracked on Apple Watch
1. The iPhone calls `startWatchApp(with:)` with a `HKWorkoutConfiguration`. The walk plan (destination, start distance, arrive-by, units, threshold) is sent through WatchConnectivity and then confirmed by the Watch.
2. The Watch starts the workout session and runs the same per-fix loop. Status transitions play Watch haptics.
3. The Watch sends metrics to the iPhone over the mirrored session every ~3 s. The iPhone's GPS stays **off**. The iPhone updates its walk screen and Live Activity from the mirrored state, **without** alert flags, so you don't get a double buzz.

### Watch-only start
From the Watch's idle screen, tapping a favorite starts a walk immediately. It uses straight-line distance, since the Watch doesn't use MapKit routing, and an arrive-by of `roundUpToMinute(now + estimate)`. Mirroring to the iPhone happens if it's reachable.

### Arrival and end
- Arrival is straight-line distance ≤ 18 m. `deltaSec` freezes at the value worked out with 0 m remaining, which is exactly arrive-by minus the arrival time, as on the web. The last few metres inside the radius therefore don't shift the result. The arrived screen shows "Arrived m:ss early/late" or "on time", the Live Activity ends showing the final state and is dismissed after 4 minutes, location updates stop, and the workout is saved to Health.
- If you press End before arriving, the walk stops and is saved to Health if it lasted at least 60 s and covered at least 50 m. Otherwise it's discarded.
- A walk tracked on the iPhone is saved with `HKWorkoutBuilder` plus `HKWorkoutRouteBuilder`, using the same activity type and data.

### Failure and edge cases
| Case | Behaviour |
|---|---|
| App force-quit mid-walk | The Live Activity has a `staleDate` of about 2 minutes past the last update, so it shows as stale. On the next launch, the saved `activeSession` is offered as Resume or End. |
| Location denied or turned off mid-walk | A banner on the walk screen, and the Live Activity shows "Location paused". The walk isn't ended. |
| Arrive-by passes before arrival | Keep counting how late you are. |
| Watch disconnects from iPhone | The Watch continues on its own. The iPhone shows "Watch disconnected — last seen m:ss ago". |
| Watch workout ends unexpectedly or the Watch app dies | The iPhone takes over: it starts its own GPS and keeps the same `Session` (the same `startAt` and `arriveBy`), so the delta stays continuous. The tracking device switches to `.phone`. |
| HealthKit denied | The Watch path is unavailable, since a workout session needs Health access. Walks are phone-only and aren't saved to Health, and Settings explains why. |
| MapKit search or routing fails | Search shows an error row. Routing falls back to straight-line distance. |

## 3. Screens

The visual language carries over from the web app: a dark background; the tokens from `src/styles.css` for `early` (#8fad9a), `late` (#c9897a) and `ontime` (#f3f1ec); monospaced digits for ±m:ss; and uppercase labels with wide letter spacing. Dynamic Type and VoiceOver are supported everywhere.

**Pace colour.** Wherever ±m:ss appears (walk screens, Live Activity, complication), its colour and its "early", "late" or "on time" label follow the web rule: within 3 s of schedule is on time (`DeltaTone` in PaceKit). The alert threshold (15, 30 or 60 s, tracked by `PaceStatus`) only decides when the iPhone or Watch buzzes. It never changes the colour.

### iPhone
1. **First launch:** one explainer screen. Permissions are requested at the moment they're needed: location on the first search or start, Health on the first walk, and notifications only if Live Activity alerts need them.
2. **Setup:**
   - A search field with type-ahead.
   - Chips below it: favorites, then recents.
   - A destination card: name, area, and "0.8 mi walk · ~16 min".
   - Arrive by: a time picker plus −1 and +1 minute buttons.
   - Start, with the tracking device shown underneath.
   - A Demo link.
   - Long-pressing a result or the destination card stars it as a favorite.
3. **Walk:** the destination and "X left · arrive-by time" at the top. Below that, a huge ±m:ss in the pace colour with an "early", "late" or "on time" label, then distance left, the heading arrow with its compass direction, speed and End. A small line says "Tracking on Apple Watch" or "Tracking on iPhone".
4. **Arrived:** the result, target versus actual arrival time, distance, duration, a "Saved to Health" confirmation, Done, and "☆ Favorite this place" if it isn't one yet.
5. **Favorites:** reorder, delete, and set a custom label.
6. **Settings:**
   - Units: Auto, Imperial or Metric. Auto means imperial when the locale is en-US, otherwise metric, as in the web app.
   - Alert threshold: 15, 30 or 60 s.
   - iPhone haptics: on or off.
   - Watch haptics: on or off.
   - Save walks to Health: on or off.
   - Prefer Apple Watch when available: on or off.
   - About.

### Apple Watch
- **Idle:** "Plan a walk on your iPhone" and the favorites list. Tapping a favorite starts a walk.
- **Walk:** page 1 shows a full-screen ±m:ss in the pace colour, a small heading arrow and the distance left. Page 2 has End.
- **Arrived:** the result and "Saved to Health".
- **Complication and Smart Stack:** ±m:ss during a walk, or the app icon when idle.

### Live Activity
The lock-screen and Dynamic Island layouts are as described in §1.

## 4. Testing

- **PaceKit (`swift test`):** unit tests for geodesy, `scheduleDeltaSec`, arrival, `PaceStatusMachine` (thresholds, the recovery margin, emitting transitions only when the status changes) and every formatter. **Golden vectors**: a Node script runs the existing TypeScript functions over a fixed set of inputs and writes their outputs to JSON, and the Swift tests check against that file.
- **Session tests (XCTest):** `WalkSession` driven by a scripted location source. Covers a full walk to arrival; where Live Activity updates and alerts fire; the route-refresh triggers; the End discard rule; resuming after a force-quit; and the phone taking over from the Watch.
- **Simulator:** GPX walks for on time, drifting behind, catching up and going off-route. Checked on the iPhone and Watch simulators.
- **Real-device checklists:** at M3, M5 and M6 the user does a short real walk and follows a written checklist.

## 5. Milestones

| # | Milestone | Exit criteria |
|---|---|---|
| M0 | Scaffold: `ios/project.yml`, four targets, PaceKit package, App Group and entitlements, `.gitignore` for the generated project | `xcodegen generate` works, and empty apps build and launch on the iPhone and Watch simulators |
| M1 | PaceKit port and golden-vector tests | `swift test` is green and matches the TypeScript output |
| M2 | iPhone core: setup, walk and arrived screens, MapKit search and routing, demo, favorites, recents, settings | A full demo walk runs on the simulator |
| M3 | Background location, Live Activity and status alerts on iPhone | A real walk with the phone locked: the Live Activity stays current and buzzes on status changes |
| M4 | Saving walks to Health from the iPhone | The walk appears in Health with its route |
| M5 | Watch app: workout session, engine, haptics, favorites start, complication | A real Watch-only walk: haptics fire and the walk is saved to Health |
| M6 | iPhone launches the Watch, mirroring, iPhone takeover | A real walk with both devices: the iPhone mirrors the Watch, and the iPhone takes over when the Watch app is killed |
| M7 | Onboarding, accessibility pass, app icon, privacy strings, TestFlight | A TestFlight build installs on the user's devices |

`CLAUDE.md` is updated at M0 to cover `ios/`.

## Known web bug (not fixed in web, avoided in Swift)

`src/hooks/use-geolocation.ts:22` works out the fallback speed as `sqrt(dLat² + dLon²) · 111320 · cos(lat)`. That applies the latitude correction to the whole distance, when it belongs only on the east-west part. The Swift port uses `haversine` between consecutive fixes instead.

## Out of scope for v1

Android; the web app; a map UI; voice prompts; walk history in the app (Health keeps the record); pause; accounts and sync; Watch-side MapKit search.
