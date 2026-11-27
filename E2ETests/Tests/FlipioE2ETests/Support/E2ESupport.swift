import E2EKit
import Testing

extension Tag {
    @Tag static var vscode: Self
    @Tag static var textedit: Self
    @Tag static var onenote: Self
    @Tag static var spotlight: Self
    @Tag static var chrome: Self
}

struct ConversionCase: Sendable, CustomTestStringConvertible {
    let id: String
    let typed: String
    let expectedText: String
    let expectedLayout: Layout

    var testDescription: String { "\(id) \(typed) → \(expectedText)" }
}

/// TEST_PLAN.md cases 1.1–1.3.
let basicConversionCases = [
    ConversionCase(id: "1.1", typed: "ghbdtn⌥", expectedText: "привет", expectedLayout: .ru),
    ConversionCase(id: "1.2", typed: "ghbdtn⌥⌥", expectedText: "ghbdtn", expectedLayout: .us),
    ConversionCase(id: "1.3", typed: "hello ghbdtn⌥", expectedText: "hello привет", expectedLayout: .ru),
]

/// Runs `body` in a fresh, empty editor of type `S` on the U.S. layout; the instance is closed afterwards.
@MainActor
func inFreshEditor<S: EditorScreen>(_ type: S.Type, _ body: (S) async throws -> Void) async throws {
    try InputSource.select(.us)
    try await S.with { screen in
        try await screen.reset()
        try await body(screen)
    }
}

/// Types `c.typed` in a fresh editor of type `S` and checks the resulting text and layout.
@MainActor
func checkConversion<S: EditorScreen>(_ c: ConversionCase, in type: S.Type, flipio: FlipioProbe) async throws {
    try await inFreshEditor(type) { app in
        try await Keyboard.type(c.typed, afterOptionTap: {
            try await flipio.awaitConversion()
            try await flipio.awaitLayoutVerified()
        })
        #expect(try await app.text() == c.expectedText)
        #expect(InputSource.current() == c.expectedLayout)
    }
}

/// TEST_PLAN.md 1.4: backspace removes a character from the typed-word buffer.
@MainActor
func checkBackspace<S: EditorScreen>(in type: S.Type, flipio: FlipioProbe) async throws {
    try await inFreshEditor(type) { app in
        try await Keyboard.type("ghbdtn")
        try await Keyboard.press(.delete, times: 2)
        try await Keyboard.tapOption()
        try await flipio.awaitConversion()
        // Wait for the switch to settle so it cannot leak into the next test.
        try await flipio.awaitLayoutVerified()
        #expect(try await app.text() == "прив")
    }
}

/// TEST_PLAN.md 2.1: the layout stays switched after conversion.
@MainActor
func checkLayoutPersists<S: EditorScreen>(in type: S.Type, flipio: FlipioProbe) async throws {
    try await inFreshEditor(type) { app in
        try await Keyboard.type("ghbdtn")
        try await Keyboard.tapOption()
        try await flipio.awaitConversion()
        let verification = try await flipio.awaitLayoutVerified()
        try await Task.sleep(for: .seconds(1))
        try await Keyboard.type("vbh")

        #expect(verification.outcome == .confirmed, "\(verification)")
        // A second press means the first switch was reverted and Flipio had to retry.
        #expect(verification.shortcutPresses == 1, "\(verification)")
        let text = try await app.text()
        #expect(text == "приветмир")
        #expect(InputSource.current() == .ru)
    }
}

/// Types `ghbdtn`, performs the case's steps, types `dfdf`, taps ⌥ and checks that only `dfdf` converted.
@MainActor
func checkBufferReset<S: EditorScreen>(_ c: BufferResetCase, in type: S.Type, flipio: FlipioProbe) async throws {
    try await inFreshEditor(type) { app in
        try await Keyboard.type("ghbdtn")
        for step in c.steps {
            switch step {
            case .key(let key, let modifiers): try await Keyboard.press(key, modifiers: modifiers)
            case .shortcut(let modifiers, let character): try await Keyboard.shortcut(modifiers, character)
            }
        }
        try await Keyboard.type("dfdf⌥", afterOptionTap: {
            try await flipio.awaitConversion()
            try await flipio.awaitLayoutVerified()
        })
        let text = try await app.text()
        #expect(text == c.expectedText)
    }
}
