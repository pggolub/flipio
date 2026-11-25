import Carbon.HIToolbox
import CoreGraphics
import os

/// Centralised helper for posting synthetic keyboard events.
enum KeySimulator {
    @discardableResult
    static func postKeyPress(
        keyCode: CGKeyCode,
        flags: CGEventFlags = []
    ) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            FlipioApp.logger.error(
                "KeySimulator.postKeyPress: failed to create CGEvent for keyCode=\(keyCode)")
            return false
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.setIntegerValueField(.eventSourceUserData, value: FlipioSyntheticEventUserData)
        keyUp.setIntegerValueField(.eventSourceUserData, value: FlipioSyntheticEventUserData)

        keyDown.post(tap: .cghidEventTap)
        usleep(10_000)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    /// Posts a shortcut the way a person types it: modifiers go down as separate key events,
    /// the main key is pressed and released, then modifiers are released after a gap.
    /// Releasing the modifier and the main key together makes macOS revert the
    /// "Select the previous input source" (⌃Space) switch ~100–500 ms later (FB24297598).
    @discardableResult
    static func postKeyChord(
        keyCode: CGKeyCode,
        modifiers: CGEventFlags,
        releaseGapMicroseconds: useconds_t = 30_000
    ) -> Bool {
        let modifierKeys: [(flag: CGEventFlags, keyCode: CGKeyCode)] = [
            (.maskControl, CGKeyCode(kVK_Control)),
            (.maskAlternate, CGKeyCode(kVK_Option)),
            (.maskShift, CGKeyCode(kVK_Shift)),
            (.maskCommand, CGKeyCode(kVK_Command)),
        ].filter { modifiers.contains($0.flag) }

        let source = CGEventSource(stateID: .combinedSessionState)

        func post(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) -> Bool {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            else {
                FlipioApp.logger.error(
                    "KeySimulator.postKeyChord: failed to create CGEvent for keyCode=\(key)")
                return false
            }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: FlipioSyntheticEventUserData)
            event.post(tap: .cghidEventTap)
            return true
        }

        var activeFlags: CGEventFlags = []
        for modifier in modifierKeys {
            activeFlags.insert(modifier.flag)
            guard post(modifier.keyCode, down: true, flags: activeFlags) else { return false }
            usleep(10_000)
        }

        guard post(keyCode, down: true, flags: activeFlags) else { return false }
        usleep(10_000)
        guard post(keyCode, down: false, flags: activeFlags) else { return false }

        usleep(releaseGapMicroseconds)

        for modifier in modifierKeys.reversed() {
            activeFlags.remove(modifier.flag)
            guard post(modifier.keyCode, down: false, flags: activeFlags) else { return false }
            usleep(10_000)
        }
        return true
    }

    static func postUnicodeString(_ text: String) {
        guard !text.isEmpty else { return }
        FlipioApp.logger.debug("simulateTyping: typing \(text.count) characters")

        let source = CGEventSource(stateID: .combinedSessionState)

        for char in text {
            let utf16 = Array(String(char).utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                FlipioApp.logger.error("simulateTyping: failed to create key events")
                return
            }

            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            keyDown.setIntegerValueField(.eventSourceUserData, value: FlipioSyntheticEventUserData)
            keyUp.setIntegerValueField(.eventSourceUserData, value: FlipioSyntheticEventUserData)

            keyDown.flags = []
            keyUp.flags = []

            keyDown.post(tap: .cgSessionEventTap)
            usleep(10_000)
            keyUp.post(tap: .cgSessionEventTap)
        }
    }
}
