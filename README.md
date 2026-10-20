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
