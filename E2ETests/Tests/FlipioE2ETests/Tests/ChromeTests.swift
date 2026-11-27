import E2EKit
import Testing

/// TEST_PLAN.md 7.2 (address bar) and 7.3 (page text field) in Chrome.
@MainActor
@Suite(
    "Chrome",
    .serialized,
    .tags(.chrome),
    .timeLimit(.minutes(2))
)
struct ChromeTests {
    let flipio = FlipioProbe()

    init() throws {
        try #require(Preflight.passed, "Preflight checks failed: \(Preflight.problems.joined(separator: "; "))")
    }

    @Test("7.2 Address bar: no trailing space, no accepted suggestion")
    func addressBar() async throws {
        try await inFreshEditor(ChromeScreen.self) { app in
            try await app.focusAddressBar()
            try await Keyboard.type("ghbdtn⌥", afterOptionTap: {
                try await flipio.awaitConversion()
                try await flipio.awaitLayoutVerified()
            })
            let text = try await app.text()
            #expect(text == "привет")
        }
    }

    @Test("7.3 Page text field", arguments: [
        ConversionCase(id: "7.3", typed: "hello ghbdtn⌥", expectedText: "hello привет", expectedLayout: .ru),
        ConversionCase(id: "7.3", typed: "hello ghbdtn⌥⌥", expectedText: "hello ghbdtn", expectedLayout: .us),
    ])
    func pageField(_ c: ConversionCase) async throws {
        try await checkConversion(c, in: ChromeScreen.self, flipio: flipio)
    }
}
