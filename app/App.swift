// Swift Matrix (Mantra): one window, a task manager of what runs on the Mac now and what starts with it.
//
// Marko, 14.10.2026: "one more Swift in the star menu, which will be the first one. We call it a Swift matrix. In the
// Swift matrix, I can just see the list, it's like a task manager of all Applications which are auto-starting and open
// right now. And I can from this one point I can close them or make them start with the computer ... It should listen
// and behave and be silent."
//
// Every row has the same two controls: QUIT (closes it now) and AUTO-START (whether it comes at the next login).
// Three sections, always drawn (nothing appears, nothing disappears; a control that cannot act is grey):
//   FROM THE STAR        the star's rows (~/.config/star-rows.json). Auto-start is the star's own memory: what was open
//                        (star-running.json) plus ALWAYS minus NEVER (~/.config/star-autostart.json, read by Star (Mantra)).
//   STARTS WITH THE MAC  login items (System Events), the apps' own helpers (one row to System Settings), LaunchAgents (~/Library and
//                        /Library). A login item is switched through System Events, a LaunchAgent with launchctl
//                        enable/disable (per user, no password); an app's own helper only in System Settings.
//   RUNNING NOW          every other app that is open; AUTO-START ON makes it a login item (opened hidden).
// Silent: it never starts by itself; the star's first row opens it.
// v4 (19.10.2026, Marko: "In the top of every user interface, there will now be an on/off switch ... If I say on, I close
// it's on"): the first row is SWIFT MATRIX  ON  OFF. OFF quits it; closing the window leaves it ON, and the star (or the
// Dock) brings the window back.
// v5 (19.10.2026, Marko: "please unify the position of the close button on every application. It's far upper right
// corner"): an ✕ at the far right of that row closes the window only; Swift Matrix stays ON.
// v6 (20.10.2026, Marko: "It's showing other apps. I wanted to just show the apps of a star menu, nothing else ... I don't
// want hammer spoon to start automatically ... it needs to be retired"): only the star's Swift apps (kind "app" in
// star-rows.json). v7 (20.10.2026): the light at the start of each row launches the app. No login items, no LaunchAgents, no other open apps, and no Hammerspoon: its Lua rows are not shown
// and Swift Matrix never asks `hs` anything. The three sections above are history.
import SwiftUI
import AppKit

let VERSION = 8
let REPO = "https://github.com/markoboskoauroville/SWIFT_MATRIX"
let HOME = NSHomeDirectory()
let CONF = HOME + "/.config"
let ROWS_FILE = CONF + "/star-rows.json"
let RUNNING_FILE = CONF + "/star-running.json"
let AUTOSTART_FILE = CONF + "/star-autostart.json"
let SELF_ID = "community.auroville.swiftmatrix"

let INK = Color(red: 0x0B/255, green: 0x0D/255, blue: 0x10/255)
let SURFACE = Color(red: 0x14/255, green: 0x1A/255, blue: 0x21/255)
let SLATE = Color(red: 0x23/255, green: 0x30/255, blue: 0x3D/255)
let SAND = Color(red: 0xF2/255, green: 0xDD/255, blue: 0xB4/255)
let AMBER = Color(red: 0xF5/255, green: 0x9E/255, blue: 0x0B/255)
let GREEN = Color(red: 0x33/255, green: 0xD1/255, blue: 0x7A/255)
let GREY = Color(red: 0x7A/255, green: 0x80/255, blue: 0x87/255)

// MARK: small helpers

func readJSON(_ p: String) -> Any? {
    guard let d = FileManager.default.contents(atPath: p) else { return nil }
    return try? JSONSerialization.jsonObject(with: d)
}
func writeJSON(_ o: Any, _ p: String) {
    try? FileManager.default.createDirectory(atPath: CONF, withIntermediateDirectories: true)
    if let d = try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys]) {
        try? d.write(to: URL(fileURLWithPath: p), options: .atomic)
    }
}
func icon(_ path: String?) -> NSImage? {
    guard let p = path, FileManager.default.fileExists(atPath: p) else { return nil }
    let i = NSWorkspace.shared.icon(forFile: p); i.size = NSSize(width: 18, height: 18); return i
}

// MARK: the model

enum Source: String { case star = "STAR" }

struct Entry: Identifiable {
    var id: String
    var name: String
    var source: Source
    var detail: String = ""
    var path: String?               // the .app, for the icon and for a login item
    var bundleID: String?
    var key: String?                // a star row's key
    var running = false
    var auto: Bool?                 // nil: not known yet
}

final class Matrix: ObservableObject {
    @Published var star: [Entry] = []
    @Published var said = ""
    private var quitting: [String: Date] = [:]     // id -> when QUIT was pressed (for FORCE QUIT after 5 s)
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    // --- the star's memory
    func autostart() -> (always: Set<String>, never: Set<String>) {
        let j = readJSON(AUTOSTART_FILE) as? [String: Any] ?? [:]
        return (Set(j["always"] as? [String] ?? []), Set(j["never"] as? [String] ?? []))
    }
    func starWillStart(_ key: String) -> Bool {
        let a = autostart()
        let was = Set(readJSON(RUNNING_FILE) as? [String] ?? [])
        return (was.contains(key) || a.always.contains(key)) && !a.never.contains(key)
    }
    func setStar(_ key: String, _ on: Bool) {
        var a = autostart()
        if on { a.always.insert(key); a.never.remove(key) } else { a.never.insert(key); a.always.remove(key) }
        writeJSON(["always": a.always.sorted(), "never": a.never.sorted(),
                   "note": "Swift Matrix (Mantra): ALWAYS starts at login whatever was open, NEVER does not start even if it was open. Read by Star (Mantra)."], AUTOSTART_FILE)
    }

    // --- one look at the star's Swift apps (every 2 s)
    func refresh() {
        let runningIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        var s: [Entry] = []
        if let d = FileManager.default.contents(atPath: ROWS_FILE), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let rows = j["rows"] as? [[String: Any]] {
            for r in rows where (r["kind"] as? String ?? "app") == "app" {
                guard let key = r["key"] as? String, let name = r["name"] as? String else { continue }
                let path = (r["app"] as? String).map { NSString(string: $0).expandingTildeInPath }
                let bid = path.flatMap { Bundle(url: URL(fileURLWithPath: $0))?.bundleIdentifier }
                var e = Entry(id: "star:" + key, name: name.replacingOccurrences(of: " \\(.*$", with: "", options: .regularExpression),
                              source: .star, detail: path.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "", path: path, bundleID: bid, key: key)
                e.running = bid == SELF_ID || (bid.map { runningIDs.contains($0) } ?? false)
                e.auto = starWillStart(key)
                s.append(e)
            }
        }
        star = s
    }

    // v7 (20.10.2026, Marko: "make Swift Matrix also a launcher ... this running light at the beginning is a launching
    // icon"): the light opens the app; one that runs comes to the front, its window back (the reopen every app handles)
    func launch(_ e: Entry) {
        guard let p = e.path else { return }
        let c = NSWorkspace.OpenConfiguration(); c.activates = true
        said = e.running ? "\(e.name): to the front" : "\(e.name): opening…"
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: p), configuration: c) { _, err in
            DispatchQueue.main.async {
                if let err = err { self.said = "\(e.name): did not open: \(err.localizedDescription)" }
                self.refresh()
            }
        }
    }

    func stubborn(_ e: Entry) -> Bool { e.running && (quitting[e.id].map { Date().timeIntervalSince($0) > 5 } ?? false) }

    // MARK: the two controls

    func quit(_ e: Entry) {
        let force = stubborn(e)
        quitting[e.id] = Date()
        guard let bid = e.bundleID else { return }
        for a in NSRunningApplication.runningApplications(withBundleIdentifier: bid) { if force { a.forceTerminate() } else { a.terminate() } }
        said = force ? "\(e.name): forced to quit" : "\(e.name): asked to quit"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refresh() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { self.refresh() }
    }

    func toggleAuto(_ e: Entry) {
        guard let k = e.key else { return }
        let on = !(e.auto ?? false)
        setStar(k, on); said = "\(e.name): " + (on ? "starts with the Mac" : "does not start with the Mac")
        refresh()
    }
}

// MARK: the window
//
// v2 (14.10.2026, Marko: "add sorting of all displayed apps with criteria name the running app to start ... Sort them at
// the top columns. Build columns for sorting like in any program"): one table, every column header sorts (a second click
// reverses), like Finder; the choice is remembered (UserDefaults sortKey / sortAscending).

extension Entry {
    var kindText: String { source.rawValue }
    var runningText: String { running ? "RUNNING" : "off" }
    var autoText: String { auto == nil ? "…" : (auto! ? "ON" : "OFF") }
    var pathText: String { detail }
    var nameKey: String { name.lowercased() }
}

struct Word: View {
    let text: String; let colour: Color; let enabled: Bool; let action: () -> Void
    // a real button (plain style), so it can also be pressed through Accessibility (a test, VoiceOver)
    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(text).font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(enabled ? colour : GREY.opacity(0.5))
                .frame(minWidth: 96).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(enabled ? SLATE : SLATE.opacity(0.35)))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!enabled)
    }
}

// ON / OFF in the CAMERA words: the lit one green, the other grey (19.10.2026)
struct OnOff: View {
    let on: Bool; let off: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {}) { word("ON", on) }.buttonStyle(.plain).help("Swift Matrix runs")
            Button(action: { DispatchQueue.main.async { off() } }) { word("OFF", !on) }.buttonStyle(.plain).help("Quit Swift Matrix")
                .accessibilityLabel("Off").accessibilityIdentifier("off")
        }.padding(.leading, 8)
    }
    func word(_ t: String, _ lit: Bool) -> some View {
        Text(t).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(lit ? GREEN : GREY)
            .frame(minWidth: 44).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(lit ? SLATE : SLATE.opacity(0.35)))
            .contentShape(Rectangle())
    }
}

// v5 (19.10.2026): the ✕ at the far upper right closes this window only; the app stays ON
struct CloseX: View {
    var body: some View {
        Button(action: { (NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible })?.performClose(nil) }) {
            Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundColor(GREY)
                .frame(width: 30, height: 30).contentShape(Rectangle())
        }.buttonStyle(.plain).help("Close the window (Swift Matrix stays ON)")
        .accessibilityLabel("Close window").accessibilityIdentifier("close")
    }
}

// v8 (31.10.2026, Marko: "On, off and top. Please build it in every application"): TOP beside ✕. Green = the window
// stays above every other window (NSWindow.level .floating), grey = as usual; remembered in "onTop", applied at launch.
struct TopWord: View {
    @AppStorage("onTop") private var onTop = false
    var body: some View {
        Button(action: { onTop.toggle(); TopWord.float(onTop) }) {
            Text("TOP").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(onTop ? GREEN : GREY)
                .frame(minWidth: 44).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(onTop ? SLATE : SLATE.opacity(0.35)))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help("Always on top: green, the window stays above every other window")
        .accessibilityLabel("Top").accessibilityIdentifier("top").accessibilityValue(onTop ? "on" : "off")
        .onAppear { DispatchQueue.main.async { TopWord.float(onTop) } }
    }
    static func float(_ on: Bool) {
        for w in NSApp.windows where w.title.hasPrefix("Swift Matrix") { w.level = on ? .floating : .normal }
    }
}

let SORTS: [String: KeyPathComparator<Entry>] = [
    "name": KeyPathComparator(\Entry.nameKey), "kind": KeyPathComparator(\Entry.kindText),
    "running": KeyPathComparator(\Entry.runningText), "auto": KeyPathComparator(\Entry.autoText),
    "path": KeyPathComparator(\Entry.pathText)]

struct MatrixView: View {
    @ObservedObject var m: Matrix
    @AppStorage("sortKey") var sortKey = "kind"
    @AppStorage("sortAscending") var sortAscending = true
    @State var order: [KeyPathComparator<Entry>] = []
    // v3 (14.10.2026, Marko: "please add a filter search filter to the Swift matrix"): name, kind and path, any case
    @State var filter = ""

    var rows: [Entry] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        let all = m.star.filter { e in
            q.isEmpty || e.name.lowercased().contains(q) || e.kindText.lowercased().contains(q) || e.detail.lowercased().contains(q)
                || (e.path ?? "").lowercased().contains(q)
        }
        guard let first = order.first else { return all }
        // the chosen column first, the name second, so equal kinds or states stay in a stable, readable order
        return all.sorted { a, b in
            if first.compare(a, b) != .orderedSame { return first.compare(a, b) == .orderedAscending }
            return a.nameKey < b.nameKey
        }
    }
    func keyOf(_ c: KeyPathComparator<Entry>) -> String {
        SORTS.first(where: { $0.value.keyPath == c.keyPath })?.key ?? "kind"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // v4 (19.10.2026): ON / OFF, the first row. It runs, so ON is lit; OFF stops the timers by quitting.
                Text("SWIFT MATRIX").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(SAND)
                OnOff(on: true) { NSApp.terminate(nil) }
                Text("\(rows.filter { $0.running }.count) running · \(rows.filter { $0.auto == true }.count) start with the Mac")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(GREY)
                Spacer()
                Text(m.said).font(.system(size: 11, design: .monospaced)).foregroundColor(AMBER).lineLimit(1)
                TopWord()
                CloseX()
            }.padding(14).padding(.trailing, -6).background(SURFACE)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(GREY)
                TextField("Filter: name, kind or path", text: $filter)
                    .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(SAND)
                Button(action: { filter = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(filter.isEmpty ? SLATE : GREY) }
                    .buttonStyle(.plain).disabled(filter.isEmpty).help("Clear the filter")
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(SLATE.opacity(0.6)))
            .padding(.horizontal, 14).padding(.bottom, 10).background(SURFACE)
            Table(rows, sortOrder: $order) {
                TableColumn("Name", value: \Entry.nameKey) { e in
                    HStack(spacing: 8) {
                        Button(action: { m.launch(e) }) {
                            ZStack {
                                Circle().fill(e.running ? GREEN : SLATE).frame(width: 18, height: 18)
                                Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                                    .foregroundColor(e.running ? INK : SAND).offset(x: 1)
                            }.frame(width: 24, height: 24).contentShape(Rectangle())
                        }.buttonStyle(.plain).help(e.running ? "Running: bring its window to the front" : "Open it")
                        if let i = icon(e.path) { Image(nsImage: i).resizable().frame(width: 16, height: 16) }
                        else { RoundedRectangle(cornerRadius: 3).fill(SLATE).frame(width: 16, height: 16) }
                        Text(e.name).font(.system(size: 12, weight: .semibold)).foregroundColor(e.running ? SAND : SAND.opacity(0.55)).lineLimit(1)
                    }.help(e.detail)
                }.width(min: 180, ideal: 240)
                TableColumn("Kind", value: \Entry.kindText) { e in
                    Text(e.kindText).font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(AMBER)
                }.width(min: 90, ideal: 170)
                TableColumn("Running", value: \Entry.runningText) { e in
                    Text(e.running ? "RUNNING" : "off").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(e.running ? GREEN : GREY)
                }.width(70)
                TableColumn("Quit") { e in
                    Word(text: m.stubborn(e) ? "FORCE QUIT" : "QUIT", colour: m.stubborn(e) ? AMBER : SAND, enabled: e.running) { m.quit(e) }
                }.width(104)
                TableColumn("Auto-start", value: \Entry.autoText) { e in
                    Word(text: e.auto == nil ? "AUTO-START …" : (e.auto! ? "AUTO-START ON" : "AUTO-START OFF"),
                         colour: (e.auto ?? false) ? GREEN : GREY, enabled: e.auto != nil) { m.toggleAuto(e) }
                        .help("Whether it starts with the Mac at the next login")
                }.width(120)
                TableColumn("Path", value: \Entry.pathText) { e in
                    Text(e.detail).font(.system(size: 10)).foregroundColor(GREY).lineLimit(1).truncationMode(.middle).help(e.detail)
                }.width(min: 160, ideal: 360)
            }
            .onAppear {
                var c = SORTS[sortKey] ?? SORTS["kind"]!
                c.order = sortAscending ? .forward : .reverse
                order = [c]
            }
            .onChange(of: order) { _, new in
                if let f = new.first { sortKey = keyOf(f); sortAscending = f.order == .forward }
            }
            HStack {
                Text("The star's apps only · QUIT closes it now · AUTO-START: what was open comes back, ON always, OFF never")
                    .font(.system(size: 10)).foregroundColor(GREY)
                Spacer()
                Text("v\(VERSION)").font(.system(size: 11, design: .monospaced)).foregroundColor(GREY)
                    .onTapGesture { NSWorkspace.shared.open(URL(string: REPO)!) }
            }.padding(.horizontal, 14).padding(.vertical, 6).background(SURFACE)
        }
        .frame(minWidth: 1000, minHeight: 520).background(INK).preferredColorScheme(.dark)
    }
}

// v4 (19.10.2026): closing the window leaves it ON; only OFF quits. The reopen (the star's row, the Dock) brings the
// window back: a window still there comes to the front, none left and SwiftUI's WindowGroup opens a new one.
final class Delegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        let ws = s.windows.filter { $0.isMiniaturized || $0.isVisible }
        if ws.isEmpty { return true }
        for w in ws { w.deminiaturize(nil); w.makeKeyAndOrderFront(nil) }
        s.activate(ignoringOtherApps: true)
        return false
    }
}

@main struct SwiftMatrix: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    @StateObject var matrix = Matrix()
    var body: some Scene {
        WindowGroup("Swift Matrix (Mantra)") { MatrixView(m: matrix) }.defaultSize(width: 1180, height: 780)
    }
}
