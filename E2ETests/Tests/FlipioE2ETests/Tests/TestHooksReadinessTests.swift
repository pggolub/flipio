@testable import E2EKit
import notify
import Testing

struct TestHooksReadinessTests {
    @Test("Preflight requires readiness from the matching Flipio process")
    func readinessRequiresMatchingPID() throws {
        let pid = Int32.max
        var token: Int32 = 0
        try #require(
            notify_register_check("\(FlipioProbe.readyName).\(pid)", &token) == NOTIFY_STATUS_OK
        )
        defer { notify_cancel(token) }

        try #require(notify_set_state(token, 0) == NOTIFY_STATUS_OK)
        #expect(!Preflight.hasTestHooks(pid))

        try #require(notify_set_state(token, UInt64(pid - 1)) == NOTIFY_STATUS_OK)
        #expect(!Preflight.hasTestHooks(pid))

        try #require(notify_set_state(token, UInt64(pid)) == NOTIFY_STATUS_OK)
        #expect(Preflight.hasTestHooks(pid))
    }
}
