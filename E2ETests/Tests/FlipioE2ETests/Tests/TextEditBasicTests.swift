import AppKit
import E2EKit
import Testing

/// TEST_PLAN.md cases 1.1–1.4, 2.x, 3.1–3.3, 4.1–4.2, 6.1–6.2 in TextEdit (plain text).
@MainActor
@Suite(
    "TextEdit – basic",
    .serialized,
    .tags(.textedit),
    .timeLimit(.minutes(1))
)
struct TextEditBasicTests {
    let flipio = FlipioProbe()

    init() throws {
        try #require(Preflight.passed, "Preflight checks failed: \(Preflight.problems.joined(separator: "; "))")
    }

    @Test("Typed-word conversion", arguments: basicConversionCases)
    func conversion(_ c: ConversionCase) async throws {
        try await checkConversion(c, in: TextEditScreen.self, flipio: flipio)
    }

    @Test("1.4 Backspace removes a character from the buffer")
    func backspace() async throws {
        try await checkBackspace(in: TextEditScreen.self, flipio: flipio)
    }

    @Test("2.1 Layout stays switched after conversion")
    func layoutPersists() async throws {
        try await checkLayoutPersists(in: TextEditScreen.self, flipio: flipio)
    }

    @Test("Buffer resets on shortcuts and navigation keys", arguments: bufferResetCases)
    func bufferReset(_ c: BufferResetCase) async throws {
        try await checkBufferReset(c, in: TextEditScreen.self, flipio: flipio)
    }

    @Test("2.2 Typing right after ⌥ lands in the new layout")
    func quickTyping() async throws {
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.type("ghbdtn⌥")
            // A fast typist resumes about 250 ms after the tap, before the layout switch is verified.
            try await Task.sleep(for: .milliseconds(250))
            try await Keyboard.type("vbh")
            try await flipio.awaitConversion()
            try await flipio.awaitLayoutVerified()
            #expect(try await app.text() == "приветмир")
            #expect(InputSource.current() == .ru)
        }
    }

    @Test("6.1 Shift does not reset the buffer")
    func shiftKeepsBuffer() async throws {
        try await checkConversion(
            ConversionCase(id: "6.1", typed: "Ghbdtn⌥", expectedText: "Привет", expectedLayout: .ru),
            in: TextEditScreen.self, flipio: flipio)
    }

    @Test("6.2 Long ⌥ hold and ⌥← do not convert")
    func noConversion() async throws {
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.type("ghbdtn")
            try await Keyboard.holdOption(for: .seconds(1.2))
            try await Keyboard.press(.left, modifiers: .maskAlternate)
            try await Task.sleep(for: .seconds(1))
            #expect(try await app.text() == "ghbdtn")
            #expect(InputSource.current() == .us)
        }
    }

    @Test("3.3 Pasted text is not retyped from the buffer")
    func paste() async throws {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let saved { pasteboard.setString(saved, forType: .string) }
        }
        pasteboard.clearContents()
        pasteboard.setString("test", forType: .string)
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.type("ghbdtn")
            try await Keyboard.shortcut(.maskCommand, "v")
            try await Keyboard.tapOption()
            // Nothing is selected, so Flipio only beeps; give it time to (wrongly) change the text.
            try await Task.sleep(for: .seconds(1))
            let text = try await app.text()
            #expect(text == "ghbdtntest")
        }
    }

    @Test("5.1 Clicking elsewhere in the text resets the buffer")
    func mouseClick() async throws {
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.type("ghbdtn")
            try await app.clickAtTextStart()
            try await Keyboard.type("dfdf⌥", afterOptionTap: {
                try await flipio.awaitConversion()
                try await flipio.awaitLayoutVerified()
            })
            let text = try await app.text()
            #expect(text == "ваваghbdtn")
        }
    }

    @Test("6.3 Tapping ⌥ in an empty document changes nothing")
    func emptyDocument() async throws {
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.tapOption()
            try await Task.sleep(for: .seconds(1))
            // Typing afterwards shows that the tap inserted nothing (copying an empty document is not observable).
            try await Keyboard.type("x")
            let text = try await app.text()
            #expect(text == "x")
            #expect(InputSource.current() == .us)
        }
    }

    @Test("6.4 A selection converts in selection mode")
    func selectionMode() async throws {
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.type("ghbdtn")
            try await Keyboard.press(.left, modifiers: .maskShift, times: 6)
            try await Keyboard.tapOption()
            let result = try await flipio.awaitConversion()
            try await Task.sleep(for: .seconds(1))
            let text = try await app.text()
            #expect(result.selectionMode)
            #expect(text == "привет")
        }
    }

    @Test("2.3 Layout survives switching to another app and back")
    func layoutAfterAppSwitch() async throws {
        try await inFreshEditor(TextEditScreen.self) { app in
            try await Keyboard.type("ghbdtn⌥", afterOptionTap: {
                try await flipio.awaitConversion()
                try await flipio.awaitLayoutVerified()
            })
            try await Task.sleep(for: .seconds(1))
            try await TextEditScreen.switchToAnotherApp()
            try await app.focus()
            try await Keyboard.type("vbh")
            let text = try await app.text()
            #expect(text == "приветмир")
            #expect(InputSource.current() == .ru)
        }
    }
}
