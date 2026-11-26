import AppKit

/// A throw-away VS Code instance with a temporary profile and one untitled editor.
/// Nothing is ever saved; `close()` kills this instance only (it is targeted by process ID).
@MainActor
public final class VSCodeScreen {
    public nonisolated static let bundleID = "com.microsoft.VSCode"

    public let pid: pid_t
    private let profile: URL

    private init(pid: pid_t, profile: URL) {
        self.pid = pid
        self.profile = profile
    }

    /// Launches a new instance, runs `body`, then closes the instance even if `body` throws.
    public static func with(_ body: (VSCodeScreen) async throws -> Void) async throws {
        let app = try await launch()
        do {
            try await body(app)
        } catch {
            app.close()
            throw error
        }
        app.close()
    }

    /// Clears the editor and Flipio's typed-word buffer (⌘ shortcuts reset it).
    public func reset() async throws {
        try await focus()
        try await Keyboard.shortcut(.maskCommand, "a")
        try await Keyboard.press(.delete)
    }

    /// The editor text, read through the clipboard (the previous clipboard is restored).
    public func text() async throws -> String {
        try await focus()
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        defer {
            pasteboard.clearContents()
            if let saved { pasteboard.setString(saved, forType: .string) }
        }
        let marker = pasteboard.changeCount
        try await Keyboard.shortcut(.maskCommand, "a")
        try await Keyboard.shortcut(.maskCommand, "c")
        try await waitUntil("VS Code to copy the editor text") { pasteboard.changeCount != marker }
        // Collapse the selection so later typing does not replace the text.
        try await Keyboard.press(.right)
        return pasteboard.string(forType: .string) ?? ""
    }

    public func close() {
        NSRunningApplication(processIdentifier: pid)?.forceTerminate()
        try? FileManager.default.removeItem(at: profile)
    }

    private func focus() async throws {
        guard let running = NSRunningApplication(processIdentifier: pid) else {
            throw E2EError.failed("VS Code test instance (pid \(pid)) is gone")
        }
        running.activate()
        try await waitUntil("VS Code test instance to become frontmost", timeout: .seconds(5)) {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        }
        try await Task.sleep(for: .milliseconds(150))
    }

    private static func launch() async throws -> VSCodeScreen {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw E2EError.failed("Visual Studio Code is not installed")
        }
        let fm = FileManager.default
        let profile = fm.temporaryDirectory.appendingPathComponent("flipio-e2e-vscode-\(UUID().uuidString)")
        let userDir = profile.appendingPathComponent("data/User")
        try fm.createDirectory(at: userDir, withIntermediateDirectories: true)
        try fm.copyItem(
            at: Paths.fixtures.appendingPathComponent("vscode/settings.json"),
            to: userDir.appendingPathComponent("settings.json")
        )

        let existing = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map(\.processIdentifier))
        let result = try Shell.run("/usr/bin/open", [
            "-n", "-a", appURL.path, "--args",
            "--user-data-dir", profile.appendingPathComponent("data").path,
            "--extensions-dir", profile.appendingPathComponent("ext").path,
            "--disable-extensions",
            "--new-window",
            "--skip-welcome",
            "--skip-release-notes",
            "--disable-workspace-trust",
        ])
        guard result.status == 0 else {
            try? fm.removeItem(at: profile)
            throw E2EError.failed("Cannot launch VS Code: \(result.output)")
        }

        var started: NSRunningApplication?
        try await waitUntil("the VS Code test instance to start", timeout: .seconds(30), interval: .milliseconds(250)) {
            started = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first { !existing.contains($0.processIdentifier) }
            return started != nil
        }
        let app = VSCodeScreen(pid: started!.processIdentifier, profile: profile)

        do {
            try await waitUntil("VS Code test window", timeout: .seconds(45), interval: .milliseconds(250)) {
                hasWindow(pid: app.pid)
            }
            try await app.focus()
            // Let the untitled editor take focus.
            try await Task.sleep(for: .seconds(1))
        } catch {
            app.close()
            throw error
        }
        return app
    }

    private static func hasWindow(pid: pid_t) -> Bool {
        var value: CFTypeRef?
        let axApp = AXUIElementCreateApplication(pid)
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else {
            return false
        }
        return !windows.isEmpty
    }
}
