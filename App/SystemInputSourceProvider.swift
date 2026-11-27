//
//  System input source detection, keyboard layout pair building,
//  and input source switching.
//

import AppKit
import Carbon.HIToolbox
import Foundation
import os

/// Information about a keyboard input source.
struct KeyboardInputSourceInfo {
    let id: String
    let name: String
    let primaryLanguage: String
    let source: TISInputSource
}

/// Provides access to system keyboard input sources.
struct SystemInputSourceProvider {

    /// Returns all selectable keyboard input sources with Unicode key layouts.
    func selectableSources() -> [KeyboardInputSourceInfo] {
        allSources().compactMap { makeSourceInfo(from: $0) }
    }

    /// Returns the ID of the currently active keyboard input source.
    func currentSourceID() -> String? {
        guard let current = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        return getStringProperty(current, key: kTISPropertyInputSourceID)
    }

    /// Returns a preferred pair of layouts based on system preferred languages.
    /// Uses the first two input sources that match the system's preferred languages.
    /// Falls back to the first two selectable sources if no language match is found.
    func selectPreferredPair() -> (
        primary: KeyboardInputSourceInfo, secondary: KeyboardInputSourceInfo
    )? {
        let sources = selectableSources()
        guard let fallbackPair = firstDistinctPair(in: sources) else { return nil }

        // Get system preferred languages
        let preferredLanguages = Locale.preferredLanguages
        guard preferredLanguages.count >= 2 else {
            return fallbackPair
        }

        // Try to match sources with preferred languages
        var matchedSources: [KeyboardInputSourceInfo] = []
        for language in preferredLanguages.prefix(2) {
            let languageCode = preferredLanguageCode(from: language)
            if let source = sources.first(where: { candidate in
                matchesLanguageCode(languageCode, source: candidate)
                    && !matchedSources.contains(where: { $0.id == candidate.id })
            }) {
                matchedSources.append(source)
            }
        }

        // If we found at least 2 matching sources, use them
        if matchedSources.count >= 2 {
            return (primary: matchedSources[0], secondary: matchedSources[1])
        }

        return fallbackPair
    }

    /// Returns the next layout in the cycle for live typing conversion.
    /// Cycles through all available layouts: A->B->C->A...
    func selectNextLayout(after currentID: String?) -> KeyboardInputSourceInfo? {
        let sources = selectableSources()
        return nextSource(after: currentID, in: sources)
    }

    // MARK: - Switching via the system shortcut

    // Symbolic hotkey IDs for input source switching (com.apple.symbolichotkeys):
    //   60 = "Select the previous input source"  (default: ⌃Space)
    //   61 = "Select next source in Input menu"  (default: ⌃⌥Space)
    // macOS versions differ on which ID gets ⌃Space; we try both.
    private static let hotkeyIDs = [60, 61]

    // macOS may revert a shortcut switch 100–600 ms later (FB24297598), so the result is
    // checked only after that window has passed.
    private static let switchVerificationDelay: TimeInterval = 0.7
    private static let switchRetryLimit = 1

    private static let tisMaxAttempts = 10
    private static let tisRetryDelay: useconds_t = 20_000

    /// Activates the given input source.
    /// Prefers simulating the system "Select the previous input source" shortcut because
    /// macOS treats it as a user switch: the system HUD is shown and, with "Automatically
    /// switch to a document's input source" enabled, the focused document remembers the new
    /// layout. A TISSelectInputSource call from another process changes only the global
    /// state, so the document restores its old layout when it regains focus.
    /// The result is verified asynchronously; a reverted switch is retried, and if the
    /// shortcut lands on a different source the target is selected via TIS as a fallback.
    func activateInputSource(id target: KeyboardInputSourceInfo) {
        FlipioApp.logger.debug("activateInputSource: activating '\(target.id, privacy: .public)'")
        let originalID = currentSourceID()
        if originalID == target.id {
            FlipioApp.logger.debug("activateInputSource: '\(target.id, privacy: .public)' is already active")
            TestHooks.layoutVerified(.alreadyActive)
            return
        }

        guard let hotkey = Self.inputSourceHotkey() else {
            FlipioApp.logger.warning(
                "activateInputSource: no enabled input source shortcut for IDs \(Self.hotkeyIDs, privacy: .public) — using TISSelectInputSource (no HUD)"
            )
            selectViaTIS(target)
            TestHooks.layoutVerified(.noHotkey)
            return
        }

        Self.post(hotkey)
        verifySwitch(
            to: target,
            from: originalID,
            hotkey: hotkey,
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            retriesLeft: Self.switchRetryLimit
        )
    }

    private func verifySwitch(
        to target: KeyboardInputSourceInfo,
        from originalID: String?,
        hotkey: HotkeyParams,
        frontmostPID: pid_t?,
        retriesLeft: Int
    ) {
        let shortcutPresses = 1 + Self.switchRetryLimit - retriesLeft
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.switchVerificationDelay) {
            let currentID = currentSourceID()
            if currentID == target.id {
                FlipioApp.logger.debug("activateInputSource: '\(target.id, privacy: .public)' confirmed")
                TestHooks.layoutVerified(.confirmed, shortcutPresses: shortcutPresses)
                return
            }
            // The user moved to another app; its layout is not ours to change.
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != frontmostPID {
                FlipioApp.logger.debug(
                    "activateInputSource: frontmost app changed, skipping verification (current='\(currentID ?? "nil", privacy: .public)')"
                )
                TestHooks.layoutVerified(.skipped, shortcutPresses: shortcutPresses)
                return
            }
            if currentID == originalID, retriesLeft > 0 {
                FlipioApp.logger.warning(
                    "activateInputSource: switch to '\(target.id, privacy: .public)' was reverted — resending shortcut"
                )
                Self.post(hotkey)
                verifySwitch(
                    to: target, from: originalID, hotkey: hotkey,
                    frontmostPID: frontmostPID, retriesLeft: retriesLeft - 1)
                return
            }
            FlipioApp.logger.warning(
                "activateInputSource: shortcut did not reach '\(target.id, privacy: .public)' (current='\(currentID ?? "nil", privacy: .public)') — falling back to TISSelectInputSource"
            )
            selectViaTIS(target)
            TestHooks.layoutVerified(.fallback, shortcutPresses: shortcutPresses)
        }
    }

    private static func post(_ hotkey: HotkeyParams) {
        FlipioApp.logger.info(
            "activateInputSource: posting shortcut keyCode=\(hotkey.keyCode, privacy: .public) modifiers=0x\(String(hotkey.modifiers, radix: 16), privacy: .public)"
        )
        KeySimulator.postKeyChord(
            keyCode: CGKeyCode(hotkey.keyCode),
            modifiers: carbonModifiersToCGEventFlags(hotkey.modifiers)
        )
    }

    private static func inputSourceHotkey() -> HotkeyParams? {
        for id in hotkeyIDs {
            if let params = readSystemHotkey(id: id) {
                return params
            }
        }
        return nil
    }

    /// Converts Carbon-style modifier mask (as stored in com.apple.symbolichotkeys) to CGEventFlags.
    private static func carbonModifiersToCGEventFlags(_ carbonMods: Int) -> CGEventFlags {
        var flags: CGEventFlags = []
        if carbonMods & 0x02_0000 != 0 { flags.insert(.maskShift) }
        if carbonMods & 0x04_0000 != 0 { flags.insert(.maskControl) }
        if carbonMods & 0x08_0000 != 0 { flags.insert(.maskAlternate) }
        if carbonMods & 0x10_0000 != 0 { flags.insert(.maskCommand) }
        return flags
    }

    private struct HotkeyParams {
        let keyCode: Int
        let modifiers: Int
    }

    /// Reads the configured shortcut for a symbolic hotkey ID from
    /// com.apple.symbolichotkeys preferences (via cfprefsd).
    /// Requires the `com.apple.security.temporary-exception.shared-preference.read-only`
    /// sandbox entitlement for `com.apple.symbolichotkeys`.
    private static func readSystemHotkey(id: Int) -> HotkeyParams? {
        guard
            let raw = CFPreferencesCopyAppValue(
                "AppleSymbolicHotKeys" as CFString,
                "com.apple.symbolichotkeys" as CFString
            ) as? [String: Any]
        else {
            FlipioApp.logger.warning(
                "readSystemHotkey(\(id, privacy: .public)): could not read com.apple.symbolichotkeys (sandbox may block cross-app prefs)"
            )
            return nil
        }
        guard let entry = raw[String(id)] as? [String: Any] else {
            FlipioApp.logger.info("readSystemHotkey(\(id, privacy: .public)): not present")
            return nil
        }
        guard let enabled = entry["enabled"] as? Bool, enabled else {
            FlipioApp.logger.info("readSystemHotkey(\(id, privacy: .public)): disabled")
            return nil
        }
        guard
            let value = entry["value"] as? [String: Any],
            let parameters = value["parameters"] as? [Any],
            parameters.count >= 3,
            let keyCode = parameters[1] as? Int,
            let modifiers = parameters[2] as? Int
        else {
            FlipioApp.logger.warning(
                "readSystemHotkey(\(id, privacy: .public)): unexpected parameters structure: \(entry, privacy: .public)")
            return nil
        }
        FlipioApp.logger.debug(
            "readSystemHotkey(\(id, privacy: .public)): found keyCode=\(keyCode, privacy: .public) modifiers=0x\(String(modifiers, radix: 16), privacy: .public)"
        )
        return HotkeyParams(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: TIS fallback

    /// Selects the source directly and verifies it, retrying briefly. Shows no HUD, and the
    /// focused document does not remember the change (see `activateInputSource`).
    @discardableResult
    private func selectViaTIS(_ target: KeyboardInputSourceInfo) -> Bool {
        for attempt in 1...Self.tisMaxAttempts {
            let status = TISSelectInputSource(target.source)
            if status != noErr {
                FlipioApp.logger.error(
                    "selectViaTIS: TISSelectInputSource failed OSStatus=\(status, privacy: .public) (attempt \(attempt, privacy: .public))"
                )
            }
            if currentSourceID() == target.id {
                FlipioApp.logger.info(
                    "selectViaTIS: '\(target.id, privacy: .public)' active after \(attempt, privacy: .public) attempt(s)"
                )
                return true
            }
            usleep(Self.tisRetryDelay)
        }
        FlipioApp.logger.error(
            "selectViaTIS: '\(target.id, privacy: .public)' not active after \(Self.tisMaxAttempts, privacy: .public) attempts (current='\(currentSourceID() ?? "nil", privacy: .public)')"
        )
        return false
    }

    private func isSelectable(_ source: TISInputSource) -> Bool {
        guard let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
        else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue() == kCFBooleanTrue
    }

    private func hasUnicodeKeyLayout(_ source: TISInputSource) -> Bool {
        return TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) != nil
    }

    private func allSources() -> [TISInputSource] {
        guard
            let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
                as? [TISInputSource]
        else {
            return []
        }
        return list
    }

    private func makeSourceInfo(from source: TISInputSource) -> KeyboardInputSourceInfo? {
        guard isSelectable(source), hasUnicodeKeyLayout(source) else { return nil }

        let id = getStringProperty(source, key: kTISPropertyInputSourceID) ?? "unknown"
        let name = getStringProperty(source, key: kTISPropertyLocalizedName) ?? id
        let primaryLanguage = getPrimaryLanguageProperty(
            source, key: kTISPropertyInputSourceLanguages)

        return KeyboardInputSourceInfo(
            id: id, name: name, primaryLanguage: primaryLanguage, source: source)
    }

    private func source(withID targetID: String) -> TISInputSource? {
        allSources().first { getStringProperty($0, key: kTISPropertyInputSourceID) == targetID }
    }

    private func firstDistinctPair(in sources: [KeyboardInputSourceInfo]) -> (
        primary: KeyboardInputSourceInfo, secondary: KeyboardInputSourceInfo
    )? {
        guard let primary = sources.first,
            let secondary = sources.first(where: { $0.id != primary.id })
        else {
            return nil
        }
        return (primary: primary, secondary: secondary)
    }

    private func nextSource(
        after currentID: String?,
        in sources: [KeyboardInputSourceInfo]
    ) -> KeyboardInputSourceInfo? {
        guard !sources.isEmpty else { return nil }
        guard let currentID,
            let currentIndex = sources.firstIndex(where: { $0.id == currentID })
        else {
            return sources.first
        }

        let nextIndex = (currentIndex + 1) % sources.count
        return sources[nextIndex]
    }

    private func matchesLanguageCode(_ languageCode: String, source: KeyboardInputSourceInfo)
        -> Bool
    {
        guard !source.primaryLanguage.isEmpty else {
            return false
        }
        return source.primaryLanguage.caseInsensitiveCompare(languageCode) == .orderedSame
    }

    private func preferredLanguageCode(from identifier: String) -> String {
        let locale = Locale(identifier: identifier)
        if let languageCode = locale.language.languageCode?.identifier {
            return languageCode
        }

        return identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            ?? identifier
    }

    private func getStringProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        let value = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue()
        return value as String
    }

    private func getPrimaryLanguageProperty(_ source: TISInputSource, key: CFString) -> String {
        guard let raw = TISGetInputSourceProperty(source, key) else { return "" }
        let value = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue()
        let languages = value as? [String] ?? []
        return languages.first ?? ""
    }
}

/// Builds keyboard layout pairs from system input sources.
enum KeyboardLayoutPairBuilder {

    /// Builds a selection with pair and source IDs from two input sources.
    static func buildSelection(
        from primary: KeyboardInputSourceInfo,
        and secondary: KeyboardInputSourceInfo
    ) -> KeyboardLayoutSelection {
        let mapping = buildMapping(from: primary, to: secondary)
        let pair = KeyboardLayoutPair(
            id: "\(primary.id)-\(secondary.id)",
            nameA: primary,
            nameB: secondary,
            aToB: mapping.aToB,
            bToA: mapping.bToA
        )
        return KeyboardLayoutSelection(
            pair: pair,
            sourceAID: primary.id,
            sourceBID: secondary.id
        )
    }

    private static func buildMapping(
        from sourceA: KeyboardInputSourceInfo,
        to sourceB: KeyboardInputSourceInfo
    ) -> (aToB: [Character: Character], bToA: [Character: Character]) {
        var aToB: [Character: Character] = [:]
        var bToA: [Character: Character] = [:]

        let modifiers: [UInt32] = [0, UInt32(shiftKey)]

        for keyCode in UInt16(0)..<UInt16(128) {
            for modifier in modifiers {
                guard
                    let aChar = translateCharacter(
                        keyCode: keyCode, modifiers: modifier, source: sourceA),
                    let bChar = translateCharacter(
                        keyCode: keyCode, modifiers: modifier, source: sourceB)
                else { continue }

                if aToB[aChar] == nil { aToB[aChar] = bChar }
                if bToA[bChar] == nil { bToA[bChar] = aChar }
            }
        }

        return (aToB: aToB, bToA: bToA)
    }

    /// Builds a one-way character mapping from source A to source B.
    static func buildOneWayMapping(
        from sourceA: KeyboardInputSourceInfo,
        to sourceB: KeyboardInputSourceInfo
    ) -> [Character: Character] {
        let mapping = buildMapping(from: sourceA, to: sourceB)
        return mapping.aToB
    }

    private static func translateCharacter(
        keyCode: UInt16,
        modifiers: UInt32,
        source: KeyboardInputSourceInfo
    ) -> Character? {
        guard
            let layoutData = TISGetInputSourceProperty(
                source.source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let data = unsafeBitCast(layoutData, to: CFData.self)
        guard let ptr = CFDataGetBytePtr(data) else { return nil }
        let keyboardLayout = UnsafeRawPointer(ptr).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        var chars: [UniChar] = Array(repeating: 0, count: 8)
        var length: Int = 0
        let modifierState = modifiers >> 8

        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            modifierState,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }

        let string = String(utf16CodeUnits: chars, count: length)
        guard string.count == 1, let char = string.first else { return nil }

        if char.unicodeScalars.allSatisfy({ CharacterSet.controlCharacters.contains($0) }) {
            return nil
        }
        return char
    }
}
