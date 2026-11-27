import AppKit

/// A throw-away instance of a text editor app, targeted by process ID so the user's own
/// instance of the same app is never touched.
@MainActor
public protocol EditorScreen: AnyObject {
    static var appName: String { get }
    var pid: pid_t { get }
    static func launch() async throws -> Self
    /// Kills this instance and removes its temporary files.
    func close()
}

extension EditorScreen {
    /// Launches a new instance, runs `body`, then closes the instance even if `body` throws.
    public static func with(_ body: (Self) async throws -> Void) async throws {
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
    /// Copying is queued behind the keystrokes already posted, so it sees their result.
    public func text() async throws -> String {
        try await focus()
        return try await copyAllText(from: Self.appName)
    }

    public func focus() async throws {
        guard let running = NSRunningApplication(processIdentifier: pid) else {
            throw E2EError.failed("\(Self.appName) test instance (pid \(pid)) is gone")
        }
        try await bringToFront(running, name: "\(Self.appName) test instance")
        try await Task.sleep(for: .milliseconds(150))
    }

    /// Brings Finder to the front, as if the user switched to another app.
    public static func switchToAnotherApp() async throws {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            throw E2EError.failed("Finder is not running")
        }
        try await bringToFront(finder, name: "Finder")
        try await Task.sleep(for: .milliseconds(300))
    }

    /// Whether the instance has opened a window; `status` receives the last Accessibility result.
    static func hasWindow(pid: pid_t, status: inout String) throws -> Bool {
        var value: CFTypeRef?
        let axApp = AXUIElementCreateApplication(pid)
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        status = "AXError \(result.rawValue)"
        if result == .apiDisabled {
            throw E2EError.failed(
                "Accessibility access is disabled; grant it to the terminal app running the tests"
            )
        }
        guard result == .success else {
            return false
        }
        guard let windows = value as? [AXUIElement] else {
            throw E2EError.failed("\(appName) returned an unexpected Accessibility window list")
        }
        status = "\(windows.count) window(s)"
        return !windows.isEmpty
    }
}

/// Selects everything in the focused text field and reads it through the clipboard (the previous
/// clipboard is restored), then collapses the selection so later typing does not replace the text.
@MainActor
public func copyAllText(from appName: String) async throws -> String {
    let pasteboard = NSPasteboard.general
    let saved = pasteboard.string(forType: .string)
    pasteboard.clearContents()
    defer {
        pasteboard.clearContents()
        if let saved { pasteboard.setString(saved, forType: .string) }
    }
    let marker = pasteboard.changeCount
    try await Keyboard.shortcut(.maskCommand, "a")
    // Slow apps (OneNote) can drop a ⌘C sent right after ⌘A, so the copy is retried.
    for attempt in 1...3 {
        try await Keyboard.shortcut(.maskCommand, "c")
        do {
            try await waitUntil("\(appName) to copy the editor text", timeout: .seconds(2)) {
                pasteboard.changeCount != marker
            }
            break
        } catch where attempt < 3 {
            continue
        }
    }
    try await Keyboard.press(.right)
    return pasteboard.string(forType: .string) ?? ""
}

/// Activates `app` and waits until it is frontmost.
@MainActor
func bringToFront(_ app: NSRunningApplication, name: String) async throws {
    app.activate()
    let isFrontmost = { NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier }
    do {
        try await waitUntil("\(name) to become frontmost", timeout: .seconds(5), isFrontmost)
    } catch {
        // Cooperative activation can be refused for an app that is already running; asking
        // Launch Services to open it again always brings it forward.
        if let url = app.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        try await waitUntil("\(name) to become frontmost", timeout: .seconds(5), isFrontmost)
    }
}
