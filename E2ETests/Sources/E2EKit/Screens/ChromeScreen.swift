import AppKit

/// A throw-away Google Chrome instance with a temporary profile and one page containing a
/// focused text field. `close()` kills this instance only (it is targeted by process ID).
@MainActor
public final class ChromeScreen: EditorScreen {
    public nonisolated static let bundleID = "com.google.Chrome"
    public static let appName = "Chrome"

    public let pid: pid_t
    private let profile: URL

    private init(pid: pid_t, profile: URL) {
        self.pid = pid
        self.profile = profile
    }

    public func close() {
        NSRunningApplication(processIdentifier: pid)?.forceTerminate()
        try? FileManager.default.removeItem(at: profile)
    }

    /// Moves the focus to the address bar (⌘L) and clears it.
    public func focusAddressBar() async throws {
        try await focus()
        try await Keyboard.shortcut(.maskCommand, "l")
        try await Task.sleep(for: .milliseconds(300))
        try await Keyboard.shortcut(.maskCommand, "a")
        try await Keyboard.press(.delete)
    }

    public static func launch() async throws -> ChromeScreen {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw E2EError.failed("Google Chrome is not installed")
        }
        let profile = try VSCodeScreen.makeProfile()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false
        configuration.arguments = [
            "--user-data-dir=\(profile.path)",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-features=Translate",
            "data:text/html,<input autofocus style='font-size:30px;width:400px'>",
        ]
        let running: NSRunningApplication
        do {
            running = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } catch {
            try? FileManager.default.removeItem(at: profile)
            throw E2EError.failed("Cannot launch Chrome at \(appURL.path): \(error)")
        }
        let app = ChromeScreen(pid: running.processIdentifier, profile: profile)

        var windowStatus = "not queried"
        do {
            try await waitUntil("Chrome test window", timeout: .seconds(30), interval: .milliseconds(250)) {
                guard !running.isTerminated else {
                    throw E2EError.failed("Chrome exited before opening its test window")
                }
                return try hasWindow(pid: app.pid, status: &windowStatus)
            }
            try await app.focus()
            // Let the page load and focus its text field.
            try await Task.sleep(for: .seconds(2))
        } catch {
            app.close()
            throw E2EError.failed("\(error). Chrome PID: \(app.pid); window query: \(windowStatus)")
        }
        return app
    }
}
