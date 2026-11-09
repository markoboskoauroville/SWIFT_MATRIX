# TAKEOVER: Swift Matrix (Mantra)

**State, 19.10.2026: v5 (ON / OFF at the top, the ✕ at the far upper right; closing the window no longer quits) built and installed. Marko to try OFF and ✕.**

(14.10.2026: v3, the filter, the first row of Star (Mantra) v4.)

Verified 14.10.2026 on the Mac: the window lists 60-odd rows (star rows, 6 login items, 13 user and 11 system
LaunchAgents, the open apps); a test LaunchAgent (`community.auroville.matrixtest`, /bin/sleep) switched AUTO-START OFF
→ `launchctl print-disabled` said disabled, ON → enabled, QUIT → unloaded; then removed. TextEdit opened and quit from
its row. No sfltool in the binary (no password dialogs).

## Next
1. Marko uses it after a restart: which windows still open by themselves? Switch them OFF here.
2. The first switch of a login item asks once for Automation (Swift Matrix → System Events): he allows it.
3. Possible: a row's OPEN (start now), a filter box.

- v8 (31.10.2026): the first row is SWIFT MATRIX ON OFF … TOP ✕; TOP keeps the window above the others (UserDefaults `onTop`); OFF, TOP and ✕ answer Accessibility as `off`, `top`, `close`.


## From the former README (9.11.2026)

# Swift Matrix (Mantra)

**A simple task manager of the Mac: what runs now and what starts with it, and from one place: QUIT it or switch its
AUTO-START.** Marko, 14.10.2026: *"In the Swift matrix, I can just see the list, it's like a task manager of all
Applications which are auto-starting and open right now. And I can from this one point I can close them or make them
start with the computer ... It should listen and behave and be silent."*

`/Applications/Swift Matrix (Mantra).app`, the first row of the star (Star (Mantra) v4). It never starts by itself.

## ON / OFF (v4, 19.10.2026)

The first row of the window is **SWIFT MATRIX  ON  OFF** (MANTRA_MANIFEST swift-apps.md). ON is lit while it runs; OFF
quits it. Closing the window leaves it ON; a click on its row in the star (or the Dock) brings the window back.
The ✕ at the far right of that row (v5, 19.10.2026: *"unify the position of the close button on every application.
It's far upper right corner"*) closes the window only.

## The table: the star's apps only (v6, 20.10.2026)

Marko, 20.10.2026: *"It's showing other apps. I wanted to just show the apps of a star menu, nothing else ... I don't want
hammer spoon to start automatically ... it needs to be retired."*

One row per Swift app of the star (kind "app" in `~/.config/star-rows.json`), nothing else: no login items, no
LaunchAgents, no other open apps, no Hammerspoon rows. Swift Matrix never calls `hs`.

A filter field above the table narrows the rows as he types: name or path, any case; the (x) clears it. Every column
header sorts, a second click reverses, the choice is remembered. Columns: Name (the light at its start: green = running; a click opens the app, or brings a running one's window
to the front, v7 20.10.2026), Kind, Running,
QUIT, AUTO-START, Path.

- QUIT quits the app; still alive after 5 s, the button offers FORCE QUIT.
- AUTO-START writes `~/.config/star-autostart.json` (ALWAYS / NEVER), read by Star (Mantra) at login. Auto-start =
  what was open when the Mac stopped (`star-running.json`) + ALWAYS − NEVER.

## Build

    ./build.sh      # swiftc, icon with the version, signed "Mantra Apps", installed in /Applications
