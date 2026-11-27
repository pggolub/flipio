import AppKit
import ApplicationServices
import Carbon.HIToolbox
import notify
import os

/// Environment checks run once before the suites. Problems are logged and the
/// suites are skipped, so a misconfigured Mac never gets typed into.
public enum Preflight {
    static let logger = Logger(subsystem: "com.flipio.e2e", category: "preflight")

    public static let problems: [String] = {
        let found = evaluate()
        if found.isEmpty {
            logger.info("E2E preflight: OK")
        } else {
            let text = found.map { "  - \($0)" }.joined(separator: "\n")
            logger.error("E2E preflight failed, tests are skipped:\n\(text, privacy: .public)")
        }
        return found
    }()

    public static var passed: Bool { problems.isEmpty }

    private static func evaluate() -> [String] {
        var problems: [String] = []

        if !AXIsProcessTrusted() {
            problems.append("Accessibility permission is missing for the app running the tests (e.g. Terminal)")
        }

        let flipio = NSRunningApplication.runningApplications(withBundleIdentifier: FlipioProbe.bundleID)
        if flipio.isEmpty {
            problems.append("Flipio is not running (start it with run.sh)")
        } else if !flipio.contains(where: { hasTestHooks($0.processIdentifier) }) {
            problems.append(
                "Flipio is not reporting live test hooks. Run ./run.sh without FLIPIO_APP to build "
                    + "the current sources, or rebuild/install Flipio and launch it with -TestHooksEnabled YES"
            )
        }

        let layouts = InputSource.enabledLayouts()
        if !layouts.contains(.us) || !layouts.contains(.ru) || layouts.count != 2 {
            problems.append("Exactly two keyboard layouts must be enabled: U.S. (or ABC) and Russian; found \(layouts)")
        }

        if !inputSourceShortcutEnabled() {
            problems.append("\"Select the previous input source\" shortcut is disabled (Keyboard → Keyboard Shortcuts → Input Sources)")
        }

        if CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift) {
            problems.append("Caps Lock is on")
        }

        if IsSecureEventInputEnabled() {
            problems.append("Secure keyboard input is on (close password fields or the app holding it)")
        }

        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: VSCodeScreen.bundleID) == nil {
            problems.append("Visual Studio Code is not installed")
        }

        return problems
    }

    static func hasTestHooks(_ pid: pid_t) -> Bool {
        var token: Int32 = 0
        let registrationStatus = notify_register_check("\(FlipioProbe.readyName).\(pid)", &token)
        guard registrationStatus == NOTIFY_STATUS_OK else {
            logger.error("Test hook readiness registration failed (status \(registrationStatus))")
            return false
        }
        defer { notify_cancel(token) }
        var state: UInt64 = 0
        let stateStatus = notify_get_state(token, &state)
        guard stateStatus == NOTIFY_STATUS_OK else {
            logger.error("Test hook readiness read failed (status \(stateStatus))")
            return false
        }
        return state == UInt64(pid)
    }

    private static func inputSourceShortcutEnabled() -> Bool {
        guard
            let hotkeys = CFPreferencesCopyAppValue(
                "AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString
            ) as? [String: Any]
        else {
            return false
        }
        return ["60", "61"].contains { id in
            (hotkeys[id] as? [String: Any])?["enabled"] as? Bool == true
        }
    }
}
