# M3 device walk: checklist

This is the M3 exit check (spec §5): a real walk with the phone locked, where the Live Activity stays current and the phone buzzes on status changes. Allow about 25 minutes, including a 10-minute walk.

## Before you go

- [ ] Install the app on your iPhone:
  - In `ios/`, run `make generate`, open `KeepThePace.xcodeproj` in Xcode, choose your iPhone and press Run.
  - Signing is automatic with team 3DLV25C9VK.
  - The first install may ask you to trust the developer in Settings › General › VPN & Device Management.
- [ ] In the app, open Settings › Alerts: set the threshold to 30 s and turn iPhone haptics on.
- [ ] Silent mode is fine either way. When silent, lock-screen alerts vibrate as long as Settings › Sounds & Haptics lets haptics play in silent mode.

## The walk (about 10 minutes)

Pick a place 0.5–0.8 mi (800–1300 m) away, and keep the arrive-by time the app suggests.

1. [ ] Type in the search field. The location prompt appears now, not at launch. Choose Allow While Using App, with Precise on.
2. [ ] The destination card shows "X mi walk · ~N min" and the line above Start says "GPS ready". Tap Start walking.
3. [ ] The first time, iOS asks on the lock screen whether to allow Live Activities from Keep the Pace. Choose Allow, and later Always Allow.
4. [ ] Lock the phone and walk normally for a minute, then look. The lock screen shows the destination, the ±m:ss in the pace colour, the distance left and the arrive-by time. The location indicator is on.
5. [ ] Stand still for about a minute. The phone buzzes and the lock screen lights up with "Falling behind", the ±m:ss and the distance to go.
6. [ ] Walk briskly until you are back within 25 s. It buzzes again: "Back on pace".
7. [ ] Unlock and keep the app open through the next status change. You feel a haptic instead of the lock-screen alert:
   - falling behind: two taps, stepping down
   - getting ahead: two taps, stepping up
   - back on pace: one soft tap
8. [ ] On an iPhone with a Dynamic Island, the home screen's Dynamic Island shows the ±m:ss on the left and the distance on the right. Touch and hold it for the full view.
9. [ ] Arrive. The lock screen shows the final ±m:ss with "ARRIVED EARLY" (or LATE, or ON TIME) under it, and "Target h:mm". It disappears about 4 minutes later, and the location indicator goes off.

## Force-quit and resume (about 5 minutes)

10. [ ] Start another walk, then swipe the app away in the app switcher. Keep walking at your normal pace.
11. [ ] After 2–3 minutes, still walking, the lock screen says "Not updating. Open Keep the Pace."
12. [ ] Open the app. A "Walk in progress" card offers Resume and End walk. Tap Resume: the walk carries on with the same arrive-by, and the same Live Activity updates again (there is no second one). There is no "Falling behind" buzz just for having been away.
13. [ ] End the walk. The Live Activity disappears at once.

## Edge cases

14. [ ] During a walk, set Settings › Privacy & Security › Location Services › Keep the Pace to Never. The walk screen shows the "Location paused" banner, the Live Activity says "Location paused", and the phone doesn't buzz while location is off. Set it back to While Using the App: tracking carries on.
15. [ ] Turn Precise Location off for Keep the Pace. The setup screen shows "Precise Location is off. Tap to allow it for this walk." Tap it and allow: "GPS ready" follows.
16. [ ] Turn off Settings › Alerts › iPhone haptics in the app. Status changes no longer buzz, in the app or on the lock screen. The Live Activity still updates.

## If something is off

Note the time and what you saw (for example, a buzz while you were walking at a steady pace), then collect the phone's log on the Mac:
1. Connect the phone to the Mac with a cable, unlock it, and trust the Mac if asked.
2. In Terminal, run `sudo log collect --device --last 1h --output ~/Desktop/walk.logarchive`.
3. Open `walk.logarchive` in Console and search for `com.iliasrafailidis.delta`.

You'll see these lines:
- "Status alert: …" for each alert the app sent, and "Status alert not shown …" when there was no Live Activity to carry one (Live Activities not allowed).
- "Walk GPS: N readings used, N stale (oldest X s), N inaccurate" when a walk ends. Many stale readings mean the 1 s stale-fix limit (spec §1) needs tuning.
- "No walking route: …" when Apple Maps couldn't route, so the distance fell back to the straight line.
- "Route refresh: N m left by street, was N m" about once a minute. When the two numbers are far apart, Apple Maps' route changed under you (for example, after a GPS fix on the next street over), and ±m:ss jumps with it. A jump like that can buzz while you walk at a steady pace.

## Results

| Steps | Pass? | Notes |
|---|---|---|
| 1–9 walk | | |
| 10–13 resume | | |
| 14–16 edge cases | | |
