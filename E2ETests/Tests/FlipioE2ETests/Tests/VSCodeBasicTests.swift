import E2EKit
import Testing

struct ConversionCase: Sendable, CustomTestStringConvertible {
    let id: String
    let typed: String
    let optionTaps: Int
    let expectedText: String
    let expectedLayout: Layout

    var testDescription: String { "\(id) \(typed) ×\(optionTaps) → \(expectedText)" }
}

/// TEST_PLAN.md cases 1.1–1.4 and 2.1 in the VS Code editor.
@MainActor
@Suite(
    "VS Code – basic",
    .serialized,
    .tags(.vscode),
    .enabled(if: Preflight.passed, "Preflight checks failed: \(Preflight.problems.joined(separator: "; "))"),
    .timeLimit(.minutes(1))
)
struct VSCodeBasicTests {
    let flipio = FlipioProbe()

    @Test(
        "Typed-word conversion",
        arguments: [
            ConversionCase(id: "1.1", typed: "ghbdtn", optionTaps: 1, expectedText: "привет", expectedLayout: .ru),
            ConversionCase(id: "1.2", typed: "ghbdtn", optionTaps: 2, expectedText: "ghbdtn", expectedLayout: .us),
            ConversionCase(id: "1.3", typed: "hello ghbdtn", optionTaps: 1, expectedText: "hello привет", expectedLayout: .ru),
        ]
    )
    func conversion(_ c: ConversionCase) async throws {
        try await inFreshEditor { app in
            try await Keyboard.type(c.typed)
            for _ in 0..<c.optionTaps {
                try await Keyboard.tapOption()
                try await flipio.awaitConversion()
                try await flipio.awaitLayoutVerified()
            }
            #expect(try await app.text() == c.expectedText)
            #expect(InputSource.current() == c.expectedLayout)
        }
    }

    @Test("1.4 Backspace removes a character from the buffer")
    func backspace() async throws {
        try await inFreshEditor { app in
            try await Keyboard.type("ghbdtn")
            try await Keyboard.press(.delete, times: 2)
            try await Keyboard.tapOption()
            try await flipio.awaitConversion()
            // Wait for the switch to settle so it cannot leak into the next test.
            try await flipio.awaitLayoutVerified()
            #expect(try await app.text() == "прив")
        }
    }

    /// Timing-sensitive (macOS may revert the ⌃Space switch, FB24297598), so it runs
    /// repeatedly; the pass rate across runs is the signal.
    @Test("2.1 Layout stays switched after conversion", arguments: 1...10)
    func layoutPersists(run: Int) async throws {
        try await inFreshEditor { app in
            try await Keyboard.type("ghbdtn")
            try await Keyboard.tapOption()
            try await flipio.awaitConversion()
            let verification = try await flipio.awaitLayoutVerified()
            try await Task.sleep(for: .seconds(1))
            try await Keyboard.type("vbh")

            #expect(verification.outcome == .confirmed, "\(verification)")
            // A second press means the first switch was reverted and Flipio had to retry.
            #expect(verification.shortcutPresses == 1, "\(verification)")
            #expect(try await app.text() == "приветмир")
            #expect(InputSource.current() == .ru)
        }
    }
}
