// The icon, drawn: the matrix itself, rows of apps, each with a dot (running) and a switch (auto-start), the version under it.
import AppKit
let S: CGFloat = 1024
let version = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "1"
let img = NSImage(size: NSSize(width: S, height: S)); img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
ctx.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 180, cornerHeight: 180, transform: nil))
ctx.setFillColor(NSColor(calibratedRed: 0.043, green: 0.051, blue: 0.063, alpha: 1).cgColor); ctx.fillPath()
let green = NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.48, alpha: 1).cgColor
let amber = NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.04, alpha: 1).cgColor
let slate = NSColor(calibratedRed: 0.14, green: 0.19, blue: 0.24, alpha: 1).cgColor
let sand = NSColor(calibratedRed: 0.95, green: 0.87, blue: 0.71, alpha: 1).cgColor
let on: [(Bool, Bool)] = [(true, true), (true, false), (false, true), (true, true), (false, false)]
for (i, (run, auto)) in on.enumerated() {
    let y = 760 - CGFloat(i) * 100
    // the running dot
    ctx.setFillColor(run ? green : slate); ctx.fillEllipse(in: CGRect(x: 200, y: y, width: 56, height: 56))
    // the name, a bar of sand
    ctx.addPath(CGPath(roundedRect: CGRect(x: 290, y: y + 16, width: i == 0 ? 300 : 230 + CGFloat(i * 23 % 90), height: 24), cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.setFillColor(sand.copy(alpha: run ? 0.9 : 0.4)!); ctx.fillPath()
    // the auto-start switch
    let sw = CGRect(x: 690, y: y + 2, width: 120, height: 52)
    ctx.addPath(CGPath(roundedRect: sw, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor(auto ? amber : slate); ctx.fillPath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: auto ? sw.maxX - 48 : sw.minX + 4, y: sw.minY + 4, width: 44, height: 44))
}
("v" + version as NSString).draw(at: NSPoint(x: 170, y: 150), withAttributes: [.font: NSFont.systemFont(ofSize: 92, weight: .semibold), .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)])
img.unlockFocus()
try! NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon_1024.png"))
