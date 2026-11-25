//
//  System input source detection, keyboard layout pair building,
//  and input source switching.
//

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

    private static let activationMaxAttempts = 10
    private static let activationRetryDelay: useconds_t = 20_000

    /// Activates the given input source via TISSelectInputSource and verifies that it became
    /// current, retrying a few times if the system has not applied it yet.
    /// The simulated system shortcut (⌃Space) is deliberately not used: macOS may revert it
    /// ~100–500 ms later when the modifier and key are released together (FB24297598).
    /// Call this before typing the replacement so the focused app already receives input
    /// in the new layout and keeps it.
    @discardableResult
    func activateInputSource(id target: KeyboardInputSourceInfo) -> Bool {
        FlipioApp.logger.debug("activateInputSource: activating '\(target.id, privacy: .public)'")
        if currentSourceID() == target.id {
            FlipioApp.logger.debug("activateInputSource: '\(target.id, privacy: .public)' is already active")
            return true
        }

        for attempt in 1...Self.activationMaxAttempts {
            let status = TISSelectInputSource(target.source)
            if status != noErr {
                FlipioApp.logger.error(
                    "activateInputSource: TISSelectInputSource failed OSStatus=\(status, privacy: .public) (attempt \(attempt, privacy: .public))"
                )
            }
            if currentSourceID() == target.id {
                FlipioApp.logger.info(
                    "activateInputSource: '\(target.id, privacy: .public)' active after \(attempt, privacy: .public) attempt(s)"
                )
                return true
            }
            usleep(Self.activationRetryDelay)
        }

        FlipioApp.logger.error(
            "activateInputSource: '\(target.id, privacy: .public)' not active after \(Self.activationMaxAttempts, privacy: .public) attempts (current='\(currentSourceID() ?? "nil", privacy: .public)')"
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
