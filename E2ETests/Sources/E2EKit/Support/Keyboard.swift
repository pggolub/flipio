import Carbon.HIToolbox
import CoreGraphics

/// Marks events posted by the test driver so the watchdog can tell them from real input.
public let E2EDriverEventMarker: Int64 = 0x4532_4554  // 'E2ET'
/// Marker Flipio puts on its own synthetic events (see FlipioSyntheticEventUserData).
let FlipioEventMarker: Int64 = 0x464C_4950  // 'FLIP'

public enum Key {
    case delete, forwardDelete, returnKey, tab, escape, space
    case left, right, up, down, home, end

    var keyCode: CGKeyCode {
        switch self {
        case .delete: return CGKeyCode(kVK_Delete)
        case .forwardDelete: return CGKeyCode(kVK_ForwardDelete)
        case .returnKey: return CGKeyCode(kVK_Return)
        case .tab: return CGKeyCode(kVK_Tab)
        case .escape: return CGKeyCode(kVK_Escape)
        case .space: return CGKeyCode(kVK_Space)
        case .left: return CGKeyCode(kVK_LeftArrow)
        case .right: return CGKeyCode(kVK_RightArrow)
        case .up: return CGKeyCode(kVK_UpArrow)
        case .down: return CGKeyCode(kVK_DownArrow)
        case .home: return CGKeyCode(kVK_Home)
        case .end: return CGKeyCode(kVK_End)
        }
    }
}

/// Posts physical key events at the HID level, as a person typing would.
/// Text is typed as key presses on the U.S. layout, so the characters that appear depend on
/// the active layout — exactly like real typing in the wrong layout.
public enum Keyboard {
    public static var interKeyDelay: Duration = .milliseconds(20)
    /// How long Option is held for a tap; Flipio accepts taps up to 0.35 s.
    public static var optionTapHold: Duration = .milliseconds(60)

    private static let source = CGEventSource(stateID: .hidSystemState)

    private static let modifierKeys: [(flag: CGEventFlags, keyCode: CGKeyCode)] = [
        (.maskCommand, CGKeyCode(kVK_Command)),
        (.maskControl, CGKeyCode(kVK_Control)),
        (.maskAlternate, CGKeyCode(kVK_Option)),
        (.maskShift, CGKeyCode(kVK_Shift)),
    ]

    public static func type(_ text: String) async throws {
        for character in text {
            guard let stroke = USLayout.stroke(for: character) else {
                throw E2EError.failed("No U.S. key produces '\(character)'")
            }
            try await press(keyCode: stroke.keyCode, modifiers: stroke.shift ? .maskShift : [])
        }
    }

    public static func press(_ key: Key, modifiers: CGEventFlags = [], times: Int = 1) async throws {
        for _ in 0..<times {
            try await press(keyCode: key.keyCode, modifiers: modifiers)
        }
    }

    /// Presses a shortcut such as ⌘A: `shortcut(.maskCommand, "a")`.
    public static func shortcut(_ modifiers: CGEventFlags, _ character: Character) async throws {
        guard let stroke = USLayout.stroke(for: character), !stroke.shift else {
            throw E2EError.failed("No unshifted U.S. key for '\(character)'")
        }
        try await press(keyCode: stroke.keyCode, modifiers: modifiers)
    }

    /// Presses and releases Option alone.
    public static func tapOption() async throws {
        try post(keyCode: CGKeyCode(kVK_Option), down: true, flags: .maskAlternate)
        try await Task.sleep(for: optionTapHold)
        try post(keyCode: CGKeyCode(kVK_Option), down: false, flags: [])
        try await Task.sleep(for: interKeyDelay)
    }

    /// Modifiers go down as separate events, then the key, then modifiers come up.
    static func press(keyCode: CGKeyCode, modifiers: CGEventFlags) async throws {
        let used = modifierKeys.filter { modifiers.contains($0.flag) }
        var flags: CGEventFlags = []
        for modifier in used {
            flags.insert(modifier.flag)
            try post(keyCode: modifier.keyCode, down: true, flags: flags)
            try await Task.sleep(for: .milliseconds(5))
        }
        try post(keyCode: keyCode, down: true, flags: flags)
        try await Task.sleep(for: .milliseconds(5))
        try post(keyCode: keyCode, down: false, flags: flags)
        for modifier in used.reversed() {
            try await Task.sleep(for: .milliseconds(5))
            flags.remove(modifier.flag)
            try post(keyCode: modifier.keyCode, down: false, flags: flags)
        }
        try await Task.sleep(for: interKeyDelay)
    }

    private static func post(keyCode: CGKeyCode, down: Bool, flags: CGEventFlags) throws {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else {
            throw E2EError.failed("Cannot create key event for keyCode \(keyCode)")
        }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: E2EDriverEventMarker)
        event.post(tap: .cghidEventTap)
    }
}

/// Key positions on the U.S. (ANSI) layout.
enum USLayout {
    struct Stroke {
        let keyCode: CGKeyCode
        let shift: Bool
    }

    private static let keys: [Character: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
        "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
        "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4, "5": kVK_ANSI_5,
        "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9, "0": kVK_ANSI_0,
        "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket,
        "]": kVK_ANSI_RightBracket, "\\": kVK_ANSI_Backslash, ";": kVK_ANSI_Semicolon,
        "'": kVK_ANSI_Quote, ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
        "`": kVK_ANSI_Grave, " ": kVK_Space,
    ]

    private static let shifted: [Character: Character] = [
        "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8",
        "(": "9", ")": "0", "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";",
        "\"": "'", "<": ",", ">": ".", "?": "/", "~": "`",
    ]

    static func stroke(for character: Character) -> Stroke? {
        if let code = keys[character] {
            return Stroke(keyCode: CGKeyCode(code), shift: false)
        }
        if character.isUppercase, let lower = character.lowercased().first, let code = keys[lower] {
            return Stroke(keyCode: CGKeyCode(code), shift: true)
        }
        if let base = shifted[character], let code = keys[base] {
            return Stroke(keyCode: CGKeyCode(code), shift: true)
        }
        return nil
    }
}
