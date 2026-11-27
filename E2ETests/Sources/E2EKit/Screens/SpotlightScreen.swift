import AppKit

/// The system Spotlight search field. It is opened with ⌘Space and closed with Escape.
@MainActor
public final class SpotlightScreen {
    private init() {}

    /// Opens Spotlight and waits for its window.
    public static func open() async throws -> SpotlightScreen {
        try await Keyboard.press(.space, modifiers: .maskCommand)
        try await waitUntil("the Spotlight window (is ⌘Space the Spotlight shortcut?)", timeout: .seconds(5)) {
            isVisible()
        }
        try await Task.sleep(for: .milliseconds(500))
        return SpotlightScreen()
    }

    /// Runs `body` in a freshly opened, empty Spotlight and always closes it afterwards.
    public static func with(_ body: (SpotlightScreen) async throws -> Void) async throws {
        let spotlight = try await open()
        do {
            try await spotlight.reset()
            try await body(spotlight)
        } catch {
            try? await spotlight.close()
            throw error
        }
        try await spotlight.close()
    }

    /// Clears the search field and Flipio's typed-word buffer (⌘ shortcuts reset it).
    public func reset() async throws {
        try await Keyboard.shortcut(.maskCommand, "a")
        try await Keyboard.press(.delete)
    }

    public func text() async throws -> String {
        try await copyAllText(from: "Spotlight")
    }

    public func close() async throws {
        try await reset()
        try await Keyboard.press(.escape)
        try await waitUntil("Spotlight to close", timeout: .seconds(5)) { !Self.isVisible() }
    }

    /// Spotlight is a window of the "Spotlight" process, or of "Siri" (floating) on macOS 27+.
    private static func isVisible() -> Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { window in
            let owner = window[kCGWindowOwnerName as String] as? String
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            return owner == "Spotlight" || (owner == "Siri" && layer > 0)
        }
    }
}
