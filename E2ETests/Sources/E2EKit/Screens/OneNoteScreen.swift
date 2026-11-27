import AppKit

/// The user's running Microsoft OneNote, which cannot be launched as a throw-away instance
/// (it needs a signed-in account). Tests type into the page that is currently open, which must
/// be the "Test Sandbox" page (checked through Accessibility) with the cursor in its body.
/// `close()` leaves OneNote running.
@MainActor
public final class OneNoteScreen: EditorScreen {
    public nonisolated static let bundleID = "com.microsoft.onenote.mac"
    public static let appName = "OneNote"

    public let pid: pid_t

    private init(pid: pid_t) {
        self.pid = pid
    }

    public func close() {}

    public static func launch() async throws -> OneNoteScreen {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            throw E2EError.failed("OneNote is not running; open the Flipio section's \"Test Sandbox\" page first")
        }
        let app = OneNoteScreen(pid: running.processIdentifier)
        var windowStatus = "not queried"
        guard try hasWindow(pid: app.pid, status: &windowStatus) else {
            throw E2EError.failed("OneNote has no open window (\(windowStatus))")
        }
        let matches = elements(named: sandboxPage, pid: app.pid)
        guard matches.contains(where: \.inSelectedRow) else {
            throw E2EError.failed(
                "OneNote must have the \"\(sandboxPage)\" page open (selected in the page list)")
        }
        try await app.focus()
        return app
    }

    static let sandboxPage = "Test Sandbox"

    private struct Match {
        /// Whether the element or an ancestor (the page-list row) is selected.
        let inSelectedRow: Bool
    }

    /// Accessibility elements whose title, value or description contains `name`.
    private static func elements(named name: String, pid: pid_t) -> [Match] {
        func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(element, name as CFString, &value)
            return value
        }
        var found: [Match] = []
        func visit(_ element: AXUIElement, depth: Int, inSelectedRow: Bool) {
            let selected = inSelectedRow || (attribute(element, kAXSelectedAttribute) as? Bool) == true
            let labels = [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute]
                .compactMap { attribute(element, $0) as? String }
            if labels.contains(where: { $0.localizedCaseInsensitiveContains(name) }) {
                found.append(Match(inSelectedRow: selected))
            }
            guard depth < 25 else { return }
            for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                visit(child, depth: depth + 1, inSelectedRow: selected)
            }
        }
        visit(AXUIElementCreateApplication(pid), depth: 0, inSelectedRow: false)
        return found
    }
}
