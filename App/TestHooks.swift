//
//  Opt-in signals for the end-to-end tests in E2ETests/.
//

import Foundation
import notify
import os

/// Posts Darwin notifications that let the end-to-end tests wait for Flipio instead of sleeping.
/// Disabled unless Flipio is launched with `-TestHooksEnabled YES` (or the default is written).
/// The result is encoded in the notification state (`notify_set_state`): Darwin notifications
/// need no run loop on the receiving side and carry no payload restrictions in the sandbox.
enum TestHooks {
    static let readyName = "com.flipio.test.ready"
    static let conversionFinishedName = "com.flipio.test.conversionFinished"
    static let layoutVerifiedName = "com.flipio.test.layoutVerified"

    private static let readyToken: Int32? = {
        guard isEnabled else { return nil }
        let pid = ProcessInfo.processInfo.processIdentifier
        var token: Int32 = 0
        let registrationStatus = notify_register_check("\(readyName).\(pid)", &token)
        guard registrationStatus == NOTIFY_STATUS_OK else {
            FlipioApp.logger.error("TestHooks: readiness registration failed (status \(registrationStatus))")
            return nil
        }
        let stateStatus = notify_set_state(token, UInt64(pid))
        guard stateStatus == NOTIFY_STATUS_OK else {
            notify_cancel(token)
            FlipioApp.logger.error("TestHooks: readiness state failed (status \(stateStatus))")
            return nil
        }
        return token
    }()

    static func start() {
        // Keep the registration alive so preflight can read the running app's PID.
        _ = readyToken
    }

    /// Final outcome of a layout switch; raw values are part of the E2ETests contract.
    enum LayoutOutcome: UInt64 {
        case confirmed = 1
        case fallback = 2
        case skipped = 3
        case alreadyActive = 4
        case noHotkey = 5
    }

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "TestHooksEnabled")
    }

    /// State: bit 0 = success, bit 1 = selection mode.
    static func conversionFinished(selectionMode: Bool, success: Bool) {
        post(conversionFinishedName, state: (success ? 1 : 0) | (selectionMode ? 2 : 0))
    }

    /// State: bits 0–7 = outcome, bits 8–15 = number of shortcut presses.
    static func layoutVerified(_ outcome: LayoutOutcome, shortcutPresses: Int = 0) {
        post(layoutVerifiedName, state: outcome.rawValue | (UInt64(shortcutPresses & 0xFF) << 8))
    }

    private static func post(_ name: String, state: UInt64) {
        guard isEnabled else { return }
        var token: Int32 = 0
        guard notify_register_check(name, &token) == NOTIFY_STATUS_OK else {
            FlipioApp.logger.error("TestHooks: notify_register_check failed for \(name, privacy: .public)")
            return
        }
        notify_set_state(token, state)
        notify_post(name)
        notify_cancel(token)
        FlipioApp.logger.debug("TestHooks: posted \(name, privacy: .public) state=\(state, privacy: .public)")
    }
}
