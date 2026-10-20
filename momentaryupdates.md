# Momentary updates: Marko's requests, word for word, saved before any code

## 14.10.2026 — startup housekeeping lost in the move from Lua to Swift; the Swift Matrix

> Also work on my transition for star menu from Swift. From Lua to Swift, actually. When the computer is starting my Specify is not killed and other startup. Functions from Lua which were doing. Um Housekeeping when the computer starts are not working. Seems like there is no keeping of the same Of the same. Behavior. And you need to develop one more Swift in the star menu, which is the which will be the first one. We call it a Swift matrix. In the Swift matrix, I can just see the list, it's like a task manager of all Applications which are auto-starting and open right now. And I can from this one point I can close them or make them start with the computer. So it's like kind of dashboard which is very simple. It can display everything that's running from my star, and I can close it remotely from here or put it to auto-run. Sometimes or what's happening now the the there are some random apps are opening every time I'm starting Starting my computer and I need to manually click on each window and close it, which is very annoying. It should not do something like this. It should listen and behave and be silent.

("Specify" = Speechify.)

1. Startup housekeeping: everything the Lua star did at login (Speechify killed, splash windows closed, the other
   jobs) done again, now from Swift, silently. — **Status:** started
2. Find why random apps open at login (login items, LaunchAgents, reopen-windows) and list them. — **Status:** started
3. **Swift Matrix (Mantra)**, the first row of the star: a simple task manager of every app running now and everything
   that starts with the Mac; from it, close any of them or switch its auto-start; mark what comes from the star.
   Silent: it opens only when chosen. — **Status:** built 14.10.2026, v2 (439b97e), first row of the star

## 14.10.2026 — sorting by columns

> in the Swift matrix, you need to add sorting of all displayed apps with criteria name the running app to start these options. Sort them at the top columns. Build columns for sorting like in any program

4. A real table with clickable column headers (ascending / descending, like Finder): Name, Kind, Running, Auto-start,
   Path; the sort choice remembered; QUIT and AUTO-START stay in every row. — **Status:** done 14.10.2026, v2
5. (14.10.2026, Marko: "why I need to put my password to Swift tool many times") The login items were read with
   `sfltool dumpbtm`, which asks for the admin password at every refresh: removed; System Events instead (Automation
   asked once, no password). — **Status:** done

## 14.10.2026 — a search filter

> please add a filter search filter to the Swift matrix

6. A search field above the table: filters the rows live as he types (name, kind and path, any case), a clear (x)
   button, together with the column sorting. — **Status:** done 14.10.2026, v3 ("agent" → 22 rows, clear → 65)

## 19.10.2026: ON / OFF at the top of the window

> When I select any of the apps, the user interface opens up. In the top of every user interface, there will now be an on/off switch ... If I say on, I close it's on ... When I just switch the check mark, and that's how I activate it. This is gone. Let's work like this. This is the workflow now.

(MANTRA_MANIFEST modules/swift-apps.md, "ON / OFF at the top of every window"; the star, STAR_SWIFT v5, now only opens apps.)

1. The first row of the main window is ON / OFF in the window's own style, named after what it switches. ON is lit while
   the app runs; OFF stops the engine cleanly and quits the app. — **Status:** built 19.10.2026, v4: the header row is
   SWIFT MATRIX  ON  OFF (OFF = NSApp.terminate; a dashboard, no engine to keep). Checked by screenshot: the row at the
   top, v4 at the foot. Marko to try OFF.
2. Closing the window leaves the app ON; the reopen (a click in the star or the Dock) shows the window again; `--login`
   still starts without a window. — **Status:** built 19.10.2026, v4: applicationShouldTerminateAfterLastWindowClosed
   false; the reopen brings a window to the front or lets the WindowGroup open a new one (it has no --login).

## 19.10.2026: the close button at the far upper right

> please unify the position of the close button on every application. It's far upper right corner. There is X to close the dialog in every dialog, same.

3. An ✕ at the window's far upper-right corner, on the ON / OFF row (ON / OFF at the left, ✕ at the right), grey; it
   closes the window only, the app stays ON. Every other dialog the app opens gets the same ✕. The title bar and its
   traffic lights stay as they are. — **Status:** built 19.10.2026, v5: ✕ (xmark, grey, 30×30) at the far right of
   the SWIFT MATRIX ON OFF row, performClose on the window. Checked by screenshot (window capture). Swift Matrix has no
   other dialog. Marko to try ✕ and OFF.

## 20.10.2026: star menu only, Hammerspoon retired

> Please fix the Swift Matrix. It's showing other apps. I wanted to just show the apps of a star menu, nothing else. understand, start menu only and I don't want hammer spoon to start automatically because we have everything already migrated to Swift so it needs to be retired

1. The table shows only the apps of the star menu (rows of `~/.config/star-rows.json`): no login items, no launch
   agents, no other open apps. — **Status:** done 20.10.2026, v6: 27 rows, every one STAR (screenshot).
2. Hammerspoon never starts automatically; Swift Matrix no longer shows or drives Hammerspoon rows. — **Status:** v6 never calls
   `hs`; Hammerspoon is not a login item (System Events) and not running after the 20.10 boot. The star still holds 7 Lua
   rows (Buckets, Sister app, Macro Recorder, Voices, Ableton Assistant A1, MIDI to MK Control, MIDI to Key Stroke):
   asked Marko whether they leave the star.
