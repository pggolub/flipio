import E2EKit
import Testing

/// TEST_PLAN.md 7.1 in Spotlight (opened with ⌘Space). The field is read after each conversion
/// in its own run, because reading resets Flipio's typed-word buffer.
@MainActor
@Suite(
    "Spotlight",
    .serialized,
    .tags(.spotlight),
    .timeLimit(.minutes(1))
)
struct SpotlightTests {
    let flipio = FlipioProbe()

    init() throws {
        try #require(Preflight.passed, "Preflight checks failed: \(Preflight.problems.joined(separator: "; "))")
    }

    @Test("7.1 Conversion in Spotlight", arguments: [
        ConversionCase(id: "7.1", typed: "hello ghbdtn⌥", expectedText: "hello привет", expectedLayout: .ru),
        ConversionCase(id: "7.1", typed: "hello ghbdtn⌥⌥", expectedText: "hello ghbdtn", expectedLayout: .us),
    ])
    func conversion(_ c: ConversionCase) async throws {
        try InputSource.select(.us)
        try await SpotlightScreen.with { spotlight in
            try await Keyboard.type(c.typed, afterOptionTap: {
                try await flipio.awaitConversion()
                try await flipio.awaitLayoutVerified()
            })
            let text = try await spotlight.text()
            #expect(text == c.expectedText)
            #expect(InputSource.current() == c.expectedLayout)
        }
    }
}
