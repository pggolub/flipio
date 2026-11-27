import E2EKit
import Testing

/// TEST_PLAN.md smoke cases 1.1–1.3 in the VS Code editor (an Electron/Chromium smoke check; the rest runs in TextEdit).
@MainActor
@Suite(
    "VS Code – basic",
    .serialized,
    .tags(.vscode),
    .timeLimit(.minutes(1))
)
struct VSCodeBasicTests {
    let flipio = FlipioProbe()

    init() throws {
        try #require(Preflight.passed, "Preflight checks failed: \(Preflight.problems.joined(separator: "; "))")
    }

    @Test("Typed-word conversion", arguments: basicConversionCases)
    func conversion(_ c: ConversionCase) async throws {
        try await checkConversion(c, in: VSCodeScreen.self, flipio: flipio)
    }
}
