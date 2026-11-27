import AppKit

/// A throw-away TextEdit instance editing an empty plain-text file in a temporary directory.
/// Autocorrection, auto-capitalization and smart substitutions are turned off for this
/// instance only (launch arguments), so typed text stays exactly as typed.
/// `close()` kills this instance only (it is targeted by process ID).
@MainActor
public final class TextEditScreen: EditorScreen {
    public nonisolated static let bundleID = "com.apple.TextEdit"
    public static let appName = "TextEdit"

    public let pid: pid_t
    private let directory: URL

    private init(pid: pid_t, directory: URL) {
        self.pid = pid
        self.directory = directory
    }

    public func close() {
        NSRunningApplication(processIdentifier: pid)?.forceTerminate()
        try? FileManager.default.removeItem(at: directory)
    }

    private static let launchArguments: [String] = [
        // Do not reopen the user's TextEdit windows in the test instance.
        "ApplePersistenceIgnoreState": "YES",
        "NSAutomaticSpellingCorrectionEnabled": "NO",
        "NSAutomaticCapitalizationEnabled": "NO",
        "NSAutomaticPeriodSubstitutionEnabled": "NO",
        "NSAutomaticTextCompletionEnabled": "NO",
        "NSAutomaticQuoteSubstitutionEnabled": "NO",
        "NSAutomaticDashSubstitutionEnabled": "NO",
        "NSAutomaticTextReplacementEnabled": "NO",
        // TextEdit's own preferences for the same features.
        "CorrectSpellingAutomatically": "NO",
        "CheckSpellingWhileTyping": "NO",
        "SmartQuotes": "NO",
        "SmartDashes": "NO",
        "TextReplacement": "NO",
    ].sorted { $0.key < $1.key }.flatMap { ["-\($0.key)", $0.value] }

    public static func launch() async throws -> TextEditScreen {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw E2EError.failed("TextEdit is not installed")
        }
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("flipio-textedit-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = directory.appendingPathComponent("test.txt")
        try Data().write(to: document)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false
        configuration.arguments = launchArguments
        let running: NSRunningApplication
        do {
            running = try await NSWorkspace.shared.open(
                [document], withApplicationAt: appURL, configuration: configuration
            )
        } catch {
            try? fm.removeItem(at: directory)
            throw E2EError.failed("Cannot launch TextEdit at \(appURL.path): \(error)")
        }
        let app = TextEditScreen(pid: running.processIdentifier, directory: directory)

        var windowStatus = "not queried"
        do {
            try await waitUntil("TextEdit test window", timeout: .seconds(15), interval: .milliseconds(100)) {
                guard !running.isTerminated else {
                    throw E2EError.failed("TextEdit exited before opening its test window")
                }
                return try hasWindow(pid: app.pid, status: &windowStatus)
            }
            try await app.focus()
        } catch {
            app.close()
            throw E2EError.failed("\(error). TextEdit PID: \(app.pid); window query: \(windowStatus)")
        }
        return app
    }

    /// Clicks at the start of the first line, moving the caret there with the mouse.
    public func clickAtTextStart() async throws {
        try await focus()
        guard let frame = Self.textAreaFrame(pid: pid) else {
            throw E2EError.failed("Cannot find the TextEdit text area through Accessibility")
        }
        try await Keyboard.click(at: CGPoint(x: frame.minX + 8, y: frame.minY + 10))
    }

    private static func textAreaFrame(pid: pid_t) -> CGRect? {
        func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(element, name as CFString, &value)
            return value
        }
        func find(_ element: AXUIElement, depth: Int) -> CGRect? {
            if attribute(element, kAXRoleAttribute) as? String == kAXTextAreaRole,
                let raw = attribute(element, "AXFrame")
            {
                var rect = CGRect.zero
                if AXValueGetValue(raw as! AXValue, .cgRect, &rect) { return rect }
            }
            guard depth < 10 else { return nil }
            for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                if let rect = find(child, depth: depth + 1) { return rect }
            }
            return nil
        }
        return find(AXUIElementCreateApplication(pid), depth: 0)
    }
}
