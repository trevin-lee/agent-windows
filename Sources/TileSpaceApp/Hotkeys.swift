// Global shortcuts through Carbon's RegisterEventHotKey, which needs no permissions.
import AppKit
import Carbon

struct Shortcut {
    let key: UInt32          // virtual key code
    let mods: NSEvent.ModifierFlags

    var carbonMods: UInt32 {
        (mods.contains(.command) ? UInt32(cmdKey) : 0) | (mods.contains(.option) ? UInt32(optionKey) : 0)
            | (mods.contains(.control) ? UInt32(controlKey) : 0) | (mods.contains(.shift) ? UInt32(shiftKey) : 0)
    }

    // what a menu item shows for it
    var keyEquivalent: String {
        switch Int(key) {
        case kVK_LeftArrow: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case kVK_RightArrow: String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case kVK_UpArrow: String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case kVK_DownArrow: String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case kVK_Return: "\r"
        case kVK_Delete: String(UnicodeScalar(NSBackspaceCharacter)!)
        case kVK_ANSI_Equal: "="
        case kVK_ANSI_Minus: "-"
        default: Self.letters[Int(key)] ?? ""
        }
    }

    static let letters: [Int: String] = [kVK_ANSI_C: "c", kVK_ANSI_D: "d", kVK_ANSI_E: "e", kVK_ANSI_F: "f",
        kVK_ANSI_G: "g", kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_R: "r", kVK_ANSI_T: "t", kVK_ANSI_U: "u"]
}

final class Hotkeys {
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, me in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            Unmanaged<Hotkeys>.fromOpaque(me!).takeUnretainedValue().handlers[id.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    var isEmpty: Bool { refs.isEmpty }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        handlers = [:]
    }

    // False if it couldn't be registered. Another app having the same shortcut doesn't count:
    // both get the key press.
    func register(_ s: Shortcut, _ handler: @escaping () -> Void) -> Bool {
        let n = UInt32(handlers.count + 1)
        var ref: EventHotKeyRef?
        let err = RegisterEventHotKey(s.key, s.carbonMods, EventHotKeyID(signature: OSType(0x746C7370), id: n),  // 'tlsp'
                                      GetApplicationEventTarget(), 0, &ref)
        guard err == noErr, let ref else { return false }
        refs.append(ref)
        handlers[n] = handler
        return true
    }
}
