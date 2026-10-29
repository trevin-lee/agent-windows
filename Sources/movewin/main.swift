// movewin: move a window to another native macOS desktop (Space) with SIP on.
//
// macOS has no API for moving a window to another desktop, and on macOS 27 it ignores
// synthetic title-bar drags. But moving a window onto another display puts it on
// whichever desktop that display is showing (that's how Rectangle's "next display"
// works). So: park the window on the other display, switch its home display to the
// target desktop, move the window back to exactly where it was.
//
//   movewin list                       every window, with its desktop and id
//   movewin spaces                     desktops per display (* = showing)
//   movewin <window> <desktop>         desktop is 1-based, on the window's display
//   movewin <window> <desktop> <display>   ...on another display ("odyssey", "built-in")
//   movewin snap <action> [<window>]   a Rectangle-style snap, e.g. left-half (no window =
//                                      the frontmost app's)
//
// <window> is a window id from `movewin list`, or text matched against
// "<app> <title>" (case-insensitive, first match). The window must be on a desktop
// that's showing. --follow stays on the target desktop instead of switching back.
// Needs two displays.
//
// Desktop shortcuts number every desktop across all displays, in display order
// (MacBook first): Ctrl+1..9, Ctrl+0 = 10, Ctrl+Option+1..6 = 11..16. These are set
// in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.
//
// Build: swift build -c release, then copy .build/release/movewin to ~/.local/bin
import AppKit
import ApplicationServices
import CoreGraphics
import MovewinCore

// set a frame and give the app time to apply it
func setFrame(_ el: AXUIElement, _ r: CGRect) {
    MovewinCore.setFrame(el, r)
    usleep(250_000)
}

// MARK: Main

var args = Array(CommandLine.arguments.dropFirst())
let follow = args.contains("--follow"); args.removeAll { $0 == "--follow" }

func die(_ s: String) -> Never { FileHandle.standardError.write((s + "\n").data(using: .utf8)!); exit(1) }

switch args.first {
case "list":
    // every titled window, with "<display> <desktop>"
    var label: [Int: String] = [:]
    for d in managedSpaces() { for (i, id) in d.spaces.enumerated() { label[id] = "\(displayName(d.uuid).prefix(10)) \(i + 1)" } }
    let l = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    var rows: [String] = []
    for w in l where (w["kCGWindowLayer"] as? Int) == 0 {
        guard let b = w["kCGWindowBounds"] as? [String: Any], let r = CGRect(dictionaryRepresentation: b as CFDictionary),
              r.width > 100, r.height > 100, let t = w["kCGWindowName"] as? String, !t.isEmpty else { continue }
        let id = w["kCGWindowNumber"] as! Int
        let where_ = spaces(of: id).compactMap { label[$0] }.joined(separator: ",")
        if where_.isEmpty { continue }
        rows.append(String(format: "%-13@ %6d  %-18@ %@", where_ as NSString, id, String((w["kCGWindowOwnerName"] as? String ?? "?").prefix(18)) as NSString, t as NSString))
    }
    rows.sorted().forEach { print($0) }
case "snap":
    guard args.count >= 2, let action = SnapAction(cliName: args[1]), action != .restore else {
        die("usage: movewin snap <action> [<window>]\nactions: " +
            SnapAction.allCases.filter { $0 != .restore }.map(\.cliName).joined(separator: " "))
    }
    let el: AXUIElement
    if args.count >= 3 {
        guard let w = find(args[2...].joined(separator: " ")) else { die("no window on a showing desktop matches '\(args[2])'") }
        guard let e = axWindow(w) else { die("can't reach \(w.app)'s window through Accessibility") }
        el = e
    } else {
        guard let e = focusedWindow() else { die("the frontmost app has no focused window") }
        el = e
    }
    guard let f = frame(of: el), let r = snap(action, window: f, last: nil, screens: screens()) else {
        die("can't \(action.title.lowercased()) this window")
    }
    setFrame(el, r.rect)
    print("\(r.result.cliName): \(Int(r.rect.minX)),\(Int(r.rect.minY)) \(Int(r.rect.width))x\(Int(r.rect.height))")
case "spaces":
    for d in managedSpaces() {
        let s = d.spaces.enumerated().map { "\($0.offset + 1)\($0.element == d.current ? "*" : "")" }.joined(separator: " ")
        print("\(displayName(d.uuid)): \(s)")
    }
case let q? where args.count == 3:
    // to a desktop on another display: show that desktop there, then move the window onto it
    guard let target = Int(args[1]), target >= 1 else { die("desktop must be a number starting at 1") }
    guard let w = find(q) else { die("no window on a showing desktop matches '\(q)'; try `movewin list`") }
    let all = managedSpaces()
    guard let d = all.first(where: { displayName($0.uuid).lowercased().contains(args[2].lowercased()) }),
          let dest = displayBounds(d.uuid) else { die("no display matches '\(args[2])'") }
    guard target <= d.spaces.count else { die("\(displayName(d.uuid)) only has \(d.spaces.count) desktops") }
    let offset = all.prefix(while: { $0.uuid != d.uuid }).reduce(0) { $0 + $1.spaces.count }
    guard let el = axWindow(w) else { die("can't reach \(w.app)'s window through Accessibility") }
    if d.current != d.spaces[target - 1] { switchTo(offset + target) }
    let size = CGSize(width: min(w.frame.width, dest.width - 80), height: min(w.frame.height, dest.height - 100))
    setFrame(el, CGRect(x: dest.midX - size.width / 2, y: dest.midY - size.height / 2, width: size.width, height: size.height))
    usleep(300_000)
    if spaces(of: w.id) == [d.spaces[target - 1]] { print("moved \(w.app) — \(w.title) to desktop \(target) on \(displayName(d.uuid))") }
    else { die("\(w.app) didn't land on desktop \(target); check `movewin list`") }
case let q? where args.count == 2:
    guard let target = Int(args[1]), target >= 1 else { die("desktop must be a number starting at 1") }
    guard let w = find(q) else { die("no window on a showing desktop matches '\(q)'; try `movewin list`") }
    // which display/desktop the window belongs to (by desktop membership, so it works
    // even for a window hanging off the edge of its screen)
    let mine = spaces(of: w.id)
    guard let d = managedSpaces().first(where: { $0.spaces.contains { mine.contains($0) } }),
          let cur = d.spaces.firstIndex(where: { mine.contains($0) }), d.spaces[cur] == d.current
    else { die("couldn't work out which desktop the window is on, or that desktop isn't showing") }
    let uuid = d.uuid
    guard target <= d.spaces.count else { die("\(displayName(uuid)) only has \(d.spaces.count) desktops") }
    if target - 1 == cur { print("already on desktop \(target)"); exit(0) }
    let all = managedSpaces()
    let offset = all.prefix(while: { $0.uuid != uuid }).reduce(0) { $0 + $1.spaces.count }
    guard offset + target <= 16 else { die("macOS only has shortcuts for 16 desktops") }
    guard let other = all.first(where: { $0.uuid != uuid }), let park = displayBounds(other.uuid)
    else { die("needs a second display to park the window on") }
    guard let el = axWindow(w) else { die("can't reach \(w.app)'s window through Accessibility") }

    // 1. park it on the other display (it joins whatever desktop is showing there)
    setFrame(el, CGRect(x: park.minX + 40, y: park.minY + 60,
                        width: min(w.frame.width, park.width - 80), height: min(w.frame.height, park.height - 100)))
    // 2. show the target desktop on the home display; 3. bring the window back
    switchTo(offset + target)
    setFrame(el, w.frame)
    usleep(300_000)
    let arrived = spaces(of: w.id) == [d.spaces[target - 1]]
    if !follow { switchTo(offset + cur + 1) }
    if arrived { print("moved \(w.app) — \(w.title) to desktop \(target) on \(displayName(uuid))") }
    else { die("\(w.app) didn't land on desktop \(target); check `movewin list`") }
default:
    print("usage: movewin list | movewin spaces | movewin <window id or text> <desktop> [<display>] [--follow] | movewin snap <action> [<window>]")
}
