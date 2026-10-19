# Swift Matrix (Mantra)

**A simple task manager of the Mac: what runs now and what starts with it, and from one place: QUIT it or switch its
AUTO-START.** Marko, 14.10.2026: *"In the Swift matrix, I can just see the list, it's like a task manager of all
Applications which are auto-starting and open right now. And I can from this one point I can close them or make them
start with the computer ... It should listen and behave and be silent."*

`/Applications/Swift Matrix (Mantra).app`, the first row of the star (Star (Mantra) v4). It never starts by itself.

## ON / OFF (v4, 19.10.2026)

The first row of the window is **SWIFT MATRIX  ON  OFF** (MANTRA_MANIFEST swift-apps.md). ON is lit while it runs; OFF
quits it. Closing the window leaves it ON; a click on its row in the star (or the Dock) brings the window back.

## The table

A filter field above the table (v3) narrows the rows as he types: name, kind or path, any case; the (x) clears it.

One table; every column header sorts, a second click reverses, the choice is remembered (Marko, 14.10.2026: *"Build
columns for sorting like in any program"*). Columns: Name (green dot = running), Kind, Running, QUIT, AUTO-START, Path.

| Kind | Where it comes from | AUTO-START switches | QUIT does |
|---|---|---|---|
| STAR | a row of `~/.config/star-rows.json` | `~/.config/star-autostart.json` (ALWAYS / NEVER), read by Star (Mantra) at login | quits the app |
| STAR · HAMMERSPOON | a Lua row still in Hammerspoon | the same file; the star applies it 20 s after login | `STAR.command(key,'stop')` |
| LOGIN ITEM | System Events login items | System Events: removed, or added back hidden (remembered in `~/.config/swift-matrix.json`) | quits the app |
| THE APP'S OWN LOGIN HELPER | apps that register their own (Path Finder, iBoysoft) | opens System Settings → Login Items | n/a |
| LAUNCH AGENT / (FOR ALL USERS) | `~/Library/LaunchAgents`, `/Library/LaunchAgents` | `launchctl disable|enable gui/<uid>/<label>` (per user, no password) | `launchctl bootout` until the next login |
| OPEN NOW | every other open app (helpers inside other apps left out) | ON makes it a login item that opens hidden | quits it; after 5 s the button offers FORCE QUIT |

For a star app, auto-start = what was open when the Mac stopped (`star-running.json`) + ALWAYS − NEVER.

## No password, ever

Login items come from System Events (macOS asks once to allow Automation). **Never `sfltool dumpbtm`**: run from an app
it asks for the admin password at every call (Marko, 14.10.2026: *"why I need to put my password to Swift tool many times"*).

## Build

    ./build.sh      # swiftc, icon with the version, signed "Mantra Apps", installed in /Applications
