@testable import E2EKit
import Foundation
import Testing

struct VSCodeLaunchTests {
    @Test("VS Code profile fits the macOS IPC socket path limit")
    @MainActor
    func profileFitsSocketPath() throws {
        let profile = try VSCodeScreen.makeProfile()
        defer { try? FileManager.default.removeItem(at: profile) }

        let socketPath = profile.appendingPathComponent("data/1.14-main.sock").path
        #expect(socketPath.utf8.count <= 103, "IPC socket path is too long: \(socketPath)")
    }
}
