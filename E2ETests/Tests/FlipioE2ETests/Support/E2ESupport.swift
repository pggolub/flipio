import E2EKit
import Testing

extension Tag {
    @Tag static var vscode: Self
}

/// Runs `body` in a fresh, empty VS Code editor on the U.S. layout; the instance is closed afterwards.
@MainActor
func inFreshEditor(_ body: (VSCodeScreen) async throws -> Void) async throws {
    try InputSource.select(.us)
    try await VSCodeScreen.with { screen in
        try await screen.reset()
        try await body(screen)
    }
}
