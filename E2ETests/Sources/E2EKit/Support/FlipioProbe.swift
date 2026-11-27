import Foundation
import notify

/// Mirrors `TestHooks.LayoutOutcome` in App/TestHooks.swift.
public enum LayoutOutcome: UInt64, Sendable {
    case confirmed = 1
    case fallback = 2
    case skipped = 3
    case alreadyActive = 4
    case noHotkey = 5
}

public struct LayoutVerification: Sendable, CustomStringConvertible {
    public let outcome: LayoutOutcome?
    /// How many times Flipio pressed the input source shortcut (2 = the first switch was reverted).
    public let shortcutPresses: Int

    public var description: String {
        "\(outcome.map { "\($0)" } ?? "unknown") after \(shortcutPresses) shortcut press(es)"
    }
}

/// Receives the Darwin notifications Flipio posts when launched with `-TestHooksEnabled YES`.
/// Create it before triggering a conversion so no signal is missed.
public final class FlipioProbe: @unchecked Sendable {
    public static let bundleID = "com.flipio.app"
    static let readyName = "com.flipio.test.ready"
    static let conversionFinishedName = "com.flipio.test.conversionFinished"
    static let layoutVerifiedName = "com.flipio.test.layoutVerified"

    private let lock = NSLock()
    private var conversions: [UInt64] = []
    private var verifications: [UInt64] = []
    private var tokens: [Int32] = []
    private let queue = DispatchQueue(label: "e2e.flipio-probe")

    public init() {
        register(Self.conversionFinishedName) { [weak self] state in self?.append(state, toConversions: true) }
        register(Self.layoutVerifiedName) { [weak self] state in self?.append(state, toConversions: false) }
    }

    deinit {
        tokens.forEach { notify_cancel($0) }
    }

    /// Waits for the next finished conversion and fails if Flipio reported an error.
    @discardableResult
    public func awaitConversion(timeout: Duration = .seconds(5)) async throws -> (selectionMode: Bool, success: Bool) {
        let state = try await next(conversions: true, timeout: timeout, what: "Flipio conversion")
        let result = (selectionMode: state & 2 != 0, success: state & 1 != 0)
        guard result.success else {
            throw E2EError.failed("Flipio reported a failed conversion (selectionMode=\(result.selectionMode))")
        }
        return result
    }

    /// Waits for the final result of the layout switch (posted ~0.7 s after the shortcut).
    @discardableResult
    public func awaitLayoutVerified(timeout: Duration = .seconds(5)) async throws -> LayoutVerification {
        let state = try await next(conversions: false, timeout: timeout, what: "Flipio layout verification")
        return LayoutVerification(outcome: LayoutOutcome(rawValue: state & 0xFF), shortcutPresses: Int((state >> 8) & 0xFF))
    }

    private func register(_ name: String, handler: @escaping (UInt64) -> Void) {
        var token: Int32 = 0
        let status = notify_register_dispatch(name, &token, queue) { token in
            var state: UInt64 = 0
            notify_get_state(token, &state)
            handler(state)
        }
        if status == NOTIFY_STATUS_OK {
            tokens.append(token)
        }
    }

    private func append(_ state: UInt64, toConversions: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if toConversions {
            conversions.append(state)
        } else {
            verifications.append(state)
        }
    }

    private func next(conversions fromConversions: Bool, timeout: Duration, what: String) async throws -> UInt64 {
        var value: UInt64?
        try await waitUntil(what, timeout: timeout) {
            lock.lock()
            defer { lock.unlock() }
            if fromConversions, !conversions.isEmpty {
                value = conversions.removeFirst()
            } else if !fromConversions, !verifications.isEmpty {
                value = verifications.removeFirst()
            }
            return value != nil
        }
        return value!
    }
}
