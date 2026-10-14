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
// Silent: it never starts by itself; the star's first row opens it, and closing the window quits it.
import SwiftUI
import AppKit

let VERSION = 3
let REPO = "https://github.com/markoboskoauroville/SWIFT_MATRIX"
let HOME = NSHomeDirectory()
let CONF = HOME + "/.config"
let ROWS_FILE = CONF + "/star-rows.json"
let RUNNING_FILE = CONF + "/star-running.json"
let AUTOSTART_FILE = CONF + "/star-autostart.json"
let MEMORY_FILE = CONF + "/swift-matrix.json"
let UID = getuid()
let HS = "/opt/homebrew/bin/hs"
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
@discardableResult
func run(_ exe: String, _ args: [String], timeout: Double = 15) -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = out
    do { try p.run() } catch { return (-1, error.localizedDescription) }
    let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
    let d = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit(); killer.cancel()
    return (p.terminationStatus, String(data: d, encoding: .utf8) ?? "")
}
func appName(_ path: String) -> String {
    // the name of the .app a path lies in, or the file's own name
    if let r = path.range(of: ".app/", options: .backwards) ?? path.range(of: ".app", options: .backwards) {
        return (String(path[..<r.lowerBound]) as NSString).lastPathComponent
    }
    return (path as NSString).lastPathComponent
}
func appBundlePath(_ raw: String) -> String? {
    let path = NSString(string: raw).expandingTildeInPath
    if path.hasSuffix(".app") { return path }
    guard let r = path.range(of: ".app/") else { return nil }
    return String(path[..<path.index(r.lowerBound, offsetBy: 4)])
}
func icon(_ path: String?) -> NSImage? {
    guard let p = path, FileManager.default.fileExists(atPath: p) else { return nil }
    let i = NSWorkspace.shared.icon(forFile: p); i.size = NSSize(width: 18, height: 18); return i
}

// MARK: the model

enum Source: String { case star = "STAR", starLua = "STAR · HAMMERSPOON", login = "LOGIN ITEM", helper = "THE APP'S OWN LOGIN HELPER",
                       agent = "LAUNCH AGENT", systemAgent = "LAUNCH AGENT (FOR ALL USERS)", app = "OPEN NOW" }

struct Entry: Identifiable {
    var id: String
    var name: String
    var source: Source
    var detail: String = ""
    var path: String?               // the .app, for the icon and for a login item
    var bundleID: String?
    var label: String?              // a LaunchAgent's label
    var key: String?                // a star row's key
    var running = false
    var auto: Bool?                 // nil: not known yet
    var canToggle = true
    var why = ""                    // why the switch is grey
}

final class Matrix: ObservableObject {
    @Published var star: [Entry] = []
    @Published var boot: [Entry] = []
    @Published var open: [Entry] = []
    @Published var said = ""
    @Published var btmReady = false
    private var btm: [Entry] = []                  // login items, from System Events (in the background)
    private var luaOn: [String: Bool] = [:]
    private var quitting: [String: Date] = [:]     // id -> when QUIT was pressed (for FORCE QUIT after 5 s)
    private var timer: Timer?

    init() {
        refresh()
        scanBTM()
        scanLua()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.scanBTM() }
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.scanLua() }
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

    // --- Hammerspoon's rows
    func scanLua() {
        DispatchQueue.global().async {
            guard FileManager.default.isExecutableFile(atPath: HS),
                  !NSRunningApplication.runningApplications(withBundleIdentifier: "org.hammerspoon.Hammerspoon").isEmpty else {
                DispatchQueue.main.async { self.luaOn = [:] }; return
            }
            let tmp = NSTemporaryDirectory() + "swift-matrix-lua.json"
            let (_, out) = run(HS, ["-t", "5", "-c", "local f=io.open('\(tmp)','w'); f:write(STAR.list()); f:close(); return 'ok'"], timeout: 8)
            var s: [String: Bool] = [:]
            if out.contains("ok"), let j = readJSON(tmp) as? [String: Any], let apps = j["apps"] as? [[String: Any]] {
                for a in apps { if let k = a["key"] as? String { s[k] = (a["on"] as? Bool) ?? false } }
            }
            DispatchQueue.main.async { self.luaOn = s; self.refresh() }
        }
    }

    // --- login items: System Events (macOS asks once for Automation, never a password).
    // (14.10.2026) Not the background-items dump: run from an app it asked Marko for his admin password at every
    // refresh. The apps' own login helpers (registered by other apps) cannot be read without it, so they are one row
    // that opens System Settings -> Login Items.
    func scanBTM() {
        DispatchQueue.global().async {
            let (st, out) = run("/usr/bin/osascript", ["-e",
                "set o to \"\"\ntell application \"System Events\"\nrepeat with i in every login item\nset o to o & (name of i) & tab & (path of i) & linefeed\nend repeat\nend tell\nreturn o"], timeout: 60)
            var list: [Entry] = []
            if st == 0 {
                for line in out.components(separatedBy: "\n") {
                    let c = line.components(separatedBy: "\t"); if c.count < 2 || c[1].isEmpty { continue }
                    let path = c[1].hasSuffix("/") ? String(c[1].dropLast()) : c[1]
                    let bid = Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier ?? path
                    list.append(Entry(id: "login:" + bid, name: c[0].replacingOccurrences(of: ".app", with: ""), source: .login,
                                      detail: path, path: path, bundleID: bid, auto: true))
                }
            }
            var h = Entry(id: "helper:settings", name: "The apps' own login helpers", source: .helper,
                          detail: st == 0 ? "Path Finder, iBoysoft MagicMenu and others register these themselves: switched in System Settings, Login Items"
                                          : "System Events did not answer (Automation for Swift Matrix not allowed yet?): " + out.trimmingCharacters(in: .whitespacesAndNewlines),
                          path: "/System/Applications/System Settings.app", auto: true)
            h.canToggle = false; h.why = "Opens System Settings, General, Login Items"
            list.append(h)
            DispatchQueue.main.async { self.btm = list; self.btmReady = true; self.refresh() }
        }
    }

    // --- LaunchAgents
    func agents() -> [Entry] {
        let (_, dis) = run("/bin/launchctl", ["print-disabled", "gui/\(UID)"])
        var disabled: [String: Bool] = [:]
        for l in dis.components(separatedBy: "\n") {
            let p = l.components(separatedBy: "\"")
            if p.count >= 3 { disabled[p[1]] = l.contains("=> disabled") || l.contains("=> true") }
        }
        let (_, list) = run("/bin/launchctl", ["list"])
        var pid: [String: Bool] = [:], loaded = Set<String>()
        for l in list.components(separatedBy: "\n").dropFirst() {
            let c = l.components(separatedBy: "\t"); if c.count < 3 { continue }
            loaded.insert(c[2]); pid[c[2]] = c[0] != "-"
        }
        var out: [Entry] = []
        for (dir, src) in [(HOME + "/Library/LaunchAgents", Source.agent), ("/Library/LaunchAgents", Source.systemAgent)] {
            for f in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where f.hasSuffix(".plist") {
                let p = dir + "/" + f
                guard let d = FileManager.default.contents(atPath: p),
                      let pl = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any],
                      let label = pl["Label"] as? String else { continue }
                let exe = (pl["Program"] as? String) ?? ((pl["ProgramArguments"] as? [String]) ?? []).first ?? ""
                let args = (pl["ProgramArguments"] as? [String]) ?? []
                // the thing it really runs: an .app among the arguments (open -a X.app), a script after python, or the program
                let target = args.first(where: { $0.contains(".app") }) ?? (args.count > 1 && exe.contains("python") ? args.last! : exe)
                let app = appBundlePath(target)
                // started at login: RunAtLoad, or KeepAlive true (a KeepAlive *dictionary* waits for its condition)
                let atLoad = ((pl["RunAtLoad"] as? Bool) ?? false) || ((pl["KeepAlive"] as? Bool) ?? false)
                let isOff = disabled[label] ?? ((pl["Disabled"] as? Bool) ?? false)
                var e = Entry(id: "agent:" + label, name: app.map { appName($0) } ?? appName(target), source: src,
                              detail: label + "  ·  " + (target as NSString).abbreviatingWithTildeInPath, path: app, label: label)
                e.running = pid[label] ?? false
                e.auto = atLoad && !isOff
                if !atLoad { e.canToggle = false; e.why = "Not started at login: it runs only when something asks for it" }
                out.append(e)
            }
        }
        return out
    }

    // --- one look at everything (every 2 s; the login items come from the last background scan)
    func refresh() {
        let apps = NSWorkspace.shared.runningApplications.filter { a in
            guard a.activationPolicy != .prohibited, let p = a.bundleURL?.path, a.bundleIdentifier != SELF_ID else { return false }
            return !p.hasPrefix("/System/Library/") && !p.hasPrefix("/Library/Apple") && !p.hasPrefix("/usr/")   // TextEdit, Notes… (/System/Applications) are his apps too
        }
        let runningIDs = Set(apps.compactMap { $0.bundleIdentifier })
        var claimed = Set<String>()

        // the star
        var s: [Entry] = []
        if let d = FileManager.default.contents(atPath: ROWS_FILE), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let rows = j["rows"] as? [[String: Any]] {
            for r in rows {
                guard let key = r["key"] as? String, let name = r["name"] as? String else { continue }
                let kind = r["kind"] as? String ?? "app"
                let path = (r["app"] as? String).map { NSString(string: $0).expandingTildeInPath }
                let bid = path.flatMap { Bundle(url: URL(fileURLWithPath: $0))?.bundleIdentifier }
                var e = Entry(id: "star:" + key, name: name.replacingOccurrences(of: " \\(.*$", with: "", options: .regularExpression),
                              source: kind == "lua" ? .starLua : .star, detail: r["about"] as? String ?? "", path: path, bundleID: bid, key: key)
                e.running = kind == "lua" ? (luaOn[key] ?? false) : (bid == SELF_ID || (bid.map { runningIDs.contains($0) } ?? false))
                if kind == "lua" { e.path = "/Applications/Hammerspoon.app" }
                e.auto = starWillStart(key)
                if let b = bid { claimed.insert(b) }
                s.append(e)
            }
        }
        claimed.insert("community.auroville.star")      // the star itself: its LaunchAgent row below

        // what starts with the Mac
        var b: [Entry] = []
        let mem = readJSON(MEMORY_FILE) as? [String: Any] ?? [:]
        let removed = mem["removedLoginItems"] as? [[String: String]] ?? []
        var seen = Set<String>()
        for var e in btm {
            if let bid = e.bundleID { e.running = runningIDs.contains(bid); claimed.insert(bid); seen.insert(bid) }
            b.append(e)
        }
        // login items switched off here stay in the list, OFF, so they can come back
        for r in removed {
            guard let path = r["path"], let bid = r["bundleID"], !seen.contains(bid) else { continue }
            var e = Entry(id: "login:" + bid, name: r["name"] ?? appName(path), source: .login, detail: path, path: path, bundleID: bid, auto: false)
            e.running = runningIDs.contains(bid); claimed.insert(bid)
            b.append(e)
        }
        for var e in agents() {
            if let p = e.path, let bid = Bundle(url: URL(fileURLWithPath: p))?.bundleIdentifier {
                e.bundleID = bid
                if runningIDs.contains(bid) { e.running = true }
                claimed.insert(bid)
            }
            if e.label == "com.mantra.star" || e.label == "com.mantra.starmenu" { e.detail = "the star's own  ·  " + e.detail }
            b.append(e)
        }

        // everything else that is open
        var o: [Entry] = []
        for a in apps {
            guard let bid = a.bundleIdentifier, !claimed.contains(bid) else { continue }
            // a helper inside another app (Claude Helper, Chrome's alerts) belongs to that app's row
            if let p = a.bundleURL?.path, p.dropLast(4).contains(".app/") { continue }
            var e = Entry(id: "app:" + bid, name: a.localizedName ?? bid, source: .app, detail: a.bundleURL?.path ?? "", path: a.bundleURL?.path, bundleID: bid, running: true, auto: false)
            if a.activationPolicy == .accessory { e.detail = "in the menu bar  ·  " + e.detail }
            o.append(e)
        }
        o.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // QUIT pressed and still alive after 5 s: the button becomes FORCE QUIT
        star = s; boot = b; open = o
    }

    func stubborn(_ e: Entry) -> Bool { e.running && (quitting[e.id].map { Date().timeIntervalSince($0) > 5 } ?? false) }

    // MARK: the two controls

    func quit(_ e: Entry) {
        let force = stubborn(e)
        quitting[e.id] = Date()
        if e.source == .starLua, let k = e.key {
            DispatchQueue.global().async { run(HS, ["-t", "20", "-c", "STAR.command('\(k)','stop')"], timeout: 25); self.scanLua() }
            said = "\(e.name): asked Hammerspoon to stop it"; return
        }
        if let l = e.label, e.source == .agent || e.source == .systemAgent {
            // a LaunchAgent stops by being taken out of launchd until the next login (KeepAlive would bring it back)
            let (st, out) = run("/bin/launchctl", ["bootout", "gui/\(UID)/\(l)"])
            said = st == 0 ? "\(e.name): stopped until the next login" : "\(e.name): launchctl said \(out.trimmingCharacters(in: .whitespacesAndNewlines))"
            refresh(); return
        }
        guard let bid = e.bundleID else { return }
        for a in NSRunningApplication.runningApplications(withBundleIdentifier: bid) { if force { a.forceTerminate() } else { a.terminate() } }
        said = force ? "\(e.name): forced to quit" : "\(e.name): asked to quit"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refresh() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { self.refresh() }
    }

    func toggleAuto(_ e: Entry) {
        let on = !(e.auto ?? false)
        switch e.source {
        case .star, .starLua:
            guard let k = e.key else { return }
            setStar(k, on); said = "\(e.name): " + (on ? "starts with the Mac" : "does not start with the Mac")
            refresh()
        case .agent, .systemAgent:
            guard let l = e.label else { return }
            let (st, out) = run("/bin/launchctl", [on ? "enable" : "disable", "gui/\(UID)/\(l)"])
            said = st == 0 ? "\(e.name): " + (on ? "starts with the Mac" : "does not start with the Mac (still running until quit)")
                           : "\(e.name): launchctl said \(out)"
            refresh()
        case .login, .app:
            guard let path = e.path, let bid = e.bundleID else { return }
            setLoginItem(name: e.name, path: path, bundleID: bid, on: on)
        case .helper:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            said = "\(e.name): its own helper is switched in System Settings → Login Items"
        }
    }

    func setLoginItem(name: String, path: String, bundleID: String, on: Bool) {
        let p = path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = on
            ? "tell application \"System Events\" to make login item at end with properties {path:\"\(p)\", hidden:true}"
            : "tell application \"System Events\" to delete (every login item whose path is \"\(p)\")"
        said = "\(name): asking System Events…"
        DispatchQueue.global().async {
            let (st, out) = run("/usr/bin/osascript", ["-e", script], timeout: 60)
            DispatchQueue.main.async {
                if st == 0 {
                    var mem = readJSON(MEMORY_FILE) as? [String: Any] ?? [:]
                    var removed = (mem["removedLoginItems"] as? [[String: String]] ?? []).filter { $0["bundleID"] != bundleID }
                    if !on { removed.append(["name": name, "path": path, "bundleID": bundleID]) }
                    mem["removedLoginItems"] = removed
                    writeJSON(mem, MEMORY_FILE)
                    self.said = "\(name): " + (on ? "a login item now (opens hidden)" : "no longer a login item")
                } else {
                    self.said = "\(name): System Events said \(out.trimmingCharacters(in: .whitespacesAndNewlines))"
                }
                self.scanBTM()
            }
        }
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
        let all = (m.star + m.boot + m.open).filter { e in
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
                Text("SWIFT MATRIX").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(SAND)
                Text("\(rows.filter { $0.running }.count) running · \(rows.filter { $0.auto == true }.count) start with the Mac")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(GREY)
                Spacer()
                Text(m.said).font(.system(size: 11, design: .monospaced)).foregroundColor(AMBER).lineLimit(1)
            }.padding(14).background(SURFACE)
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
                        Circle().fill(e.running ? GREEN : SLATE).frame(width: 8, height: 8)
                        if let i = icon(e.path) { Image(nsImage: i).resizable().frame(width: 16, height: 16) }
                        else { RoundedRectangle(cornerRadius: 3).fill(SLATE).frame(width: 16, height: 16) }
                        Text(e.name).font(.system(size: 12, weight: .semibold)).foregroundColor(e.running ? SAND : SAND.opacity(0.55)).lineLimit(1)
                    }.help(e.detail)
                }.width(min: 180, ideal: 240)
                TableColumn("Kind", value: \Entry.kindText) { e in
                    Text(e.kindText).font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(e.source == .star || e.source == .starLua ? AMBER : GREY)
                }.width(min: 90, ideal: 170)
                TableColumn("Running", value: \Entry.runningText) { e in
                    Text(e.running ? "RUNNING" : "off").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(e.running ? GREEN : GREY)
                }.width(70)
                TableColumn("Quit") { e in
                    Word(text: m.stubborn(e) ? "FORCE QUIT" : "QUIT", colour: m.stubborn(e) ? AMBER : SAND, enabled: e.running) { m.quit(e) }
                }.width(104)
                TableColumn("Auto-start", value: \Entry.autoText) { e in
                    Word(text: e.auto == nil ? "AUTO-START …" : (e.auto! ? "AUTO-START ON" : "AUTO-START OFF"),
                         colour: (e.auto ?? false) ? GREEN : GREY, enabled: e.auto != nil && (e.canToggle || e.source == .helper)) { m.toggleAuto(e) }
                        .help(e.why.isEmpty ? "Whether it starts with the Mac at the next login" : e.why)
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
                Text("QUIT closes it now · AUTO-START decides the next login · the star's apps: what was open comes back, ON always, OFF never")
                    .font(.system(size: 10)).foregroundColor(GREY)
                Spacer()
                Text("v\(VERSION)").font(.system(size: 11, design: .monospaced)).foregroundColor(GREY)
                    .onTapGesture { NSWorkspace.shared.open(URL(string: REPO)!) }
            }.padding(.horizontal, 14).padding(.vertical, 6).background(SURFACE)
        }
        .frame(minWidth: 1000, minHeight: 520).background(INK).preferredColorScheme(.dark)
    }
}

// a dashboard, not an engine: closing the window quits it
final class Delegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

@main struct SwiftMatrix: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    @StateObject var matrix = Matrix()
    var body: some Scene {
        WindowGroup("Swift Matrix (Mantra)") { MatrixView(m: matrix) }.defaultSize(width: 1180, height: 780)
    }
}
