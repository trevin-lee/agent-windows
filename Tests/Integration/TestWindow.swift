// A plain window for the integration test to move around. It writes its own frame
// ("x y width height", top-left origin like Accessibility) to the file given as the first
// argument, ten times a second.
//   swiftc Tests/Integration/TestWindow.swift -o build/TestWindow && build/TestWindow /tmp/frame
import AppKit

let out = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 800, height: 600),
                      styleMask: [.titled, .resizable, .closable, .miniaturizable], backing: .buffered, defer: false)
window.title = "agent-windows test"
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    let f = window.frame, mainHeight = NSScreen.screens[0].frame.height
    let line = "\(Int(f.minX)) \(Int(mainHeight - f.maxY)) \(Int(f.width)) \(Int(f.height))\n"
    try? line.write(toFile: out, atomically: true, encoding: .utf8)
}
app.run()
