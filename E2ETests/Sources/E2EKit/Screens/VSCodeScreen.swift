import AppKit
import Darwin

/// A throw-away VS Code instance with a temporary profile and one untitled editor.
/// Nothing is ever saved; `close()` kills this instance only (it is targeted by process ID).
@MainActor
public final class VSCodeScreen: EditorScreen {
    public nonisolated static let bundleID = "com.microsoft.VSCode"
    public static let appName = "VS Code"

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

    static func makeProfile() throws -> URL {
        // VS Code's IPC socket lives under data/; macOS limits socket paths to 103 bytes.
        var template = Array(
            FileManager.default.temporaryDirectory.appendingPathComponent("flipio-XXXXXX").path.utf8CString
        )
        guard mkdtemp(&template) != nil else {
            throw E2EError.failed("Cannot create VS Code test profile (errno \(errno))")
        }
        return URL(fileURLWithPath: String(cString: template), isDirectory: true)
    }

    public static func launch() async throws -> VSCodeScreen {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw E2EError.failed("Visual Studio Code is not installed")
        }
        let fm = FileManager.default
        let profile = try makeProfile()
        let userDir = profile.appendingPathComponent("data/User")
        try fm.createDirectory(at: userDir, withIntermediateDirectories: true)
        try fm.copyItem(
            at: Paths.fixtures.appendingPathComponent("vscode/settings.json"),
            to: userDir.appendingPathComponent("settings.json")
        )

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false
        configuration.arguments = [
            "--user-data-dir", profile.appendingPathComponent("data").path,
            "--extensions-dir", profile.appendingPathComponent("ext").path,
            "--disable-extensions",
            "--new-window",
            "--skip-welcome",
            "--skip-release-notes",
            "--disable-workspace-trust",
        ]
        let running: NSRunningApplication
        do {
            running = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } catch {
            throw E2EError.failed("Cannot launch VS Code at \(appURL.path): \(error). Test profile: \(profile.path)")
        }
        let app = VSCodeScreen(pid: running.processIdentifier, profile: profile)

        var windowStatus = "not queried"
        do {
            try await waitUntil("VS Code test window", timeout: .seconds(45), interval: .milliseconds(250)) {
                guard !running.isTerminated else {
                    throw E2EError.failed("VS Code exited before opening its test window")
                }
                return try hasWindow(pid: app.pid, status: &windowStatus)
            }
            try await app.focus()
            // Let the untitled editor take focus.
            try await Task.sleep(for: .seconds(1))
        } catch {
            running.forceTerminate()
            throw E2EError.failed(
                "\(error). VS Code PID: \(app.pid); window query: \(windowStatus). "
                    + "Test profile retained for diagnostics: \(profile.path)"
            )
        }
        return app
    }
}
