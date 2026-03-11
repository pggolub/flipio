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
