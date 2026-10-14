# LESSONS

1. (14.10.2026) `sfltool dumpbtm` from an app asks for the admin password at every call. A 2-second refresh made it a
   password storm. Read login items through System Events instead; never call sfltool from an app.
2. (14.10.2026) A SwiftUI `Text` with `onTapGesture` cannot be pressed through Accessibility; a `Button(.plain)` can,
   so the controls are buttons (tests press them with AXPress: row → cell group → button).
3. (14.10.2026) `KeepAlive` as a dictionary does not mean "starts at login"; only `RunAtLoad` or `KeepAlive = true` do.
