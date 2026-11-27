import E2EKit
import Foundation
import Testing

/// TEST_PLAN.md 7.5 in the running OneNote. It types into your real OneNote and fails unless the
/// "Test Sandbox" page of the "Flipio" section is open with the cursor in its body.
/// The page body is cleared (⌘A ⌫) before and after the test.
@MainActor
@Suite(
    "OneNote",
    .serialized,
    .tags(.onenote),
    .timeLimit(.minutes(1))
)
struct OneNoteTests {
    let flipio = FlipioProbe()

    init() throws {
        try #require(Preflight.passed, "Preflight checks failed: \(Preflight.problems.joined(separator: "; "))")
    }

    @Test("7.5 Conversion round trip with select-and-delete")
    func roundTrip() async throws {
        try await inFreshEditor(OneNoteScreen.self) { app in
            try await Keyboard.type("hello ghbdtn⌥⌥", afterOptionTap: {
                try await flipio.awaitConversion()
                try await flipio.awaitLayoutVerified()
            })
            // Typing replaces a leftover selection, so "!" also proves no text is left selected.
            try await Keyboard.type("!")
            let text = try await app.text()
            try await app.reset()
            // OneNote may auto-capitalize the first letter and appends a newline when copying a paragraph;
            // neither is Flipio's concern.
            #expect(text.trimmingCharacters(in: .newlines).lowercased() == "hello ghbdtn!")
            #expect(InputSource.current() == .us)
        }
    }
}
