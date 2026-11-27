import CoreGraphics
import E2EKit
import Testing

/// One keystroke performed between typing `ghbdtn` and typing `dfdf`.
enum Step: Sendable {
    case key(Key, CGEventFlags = [])
    case shortcut(CGEventFlags, Character)
}

/// TEST_PLAN.md 3.1, 3.2, 4.1 and 4.2: after `step`, only the `dfdf` typed next converts.
struct BufferResetCase: Sendable, CustomTestStringConvertible {
    let id: String
    let name: String
    let steps: [Step]
    let expectedText: String

    var testDescription: String { "\(id) \(name)" }
}

let bufferResetCases = [
    BufferResetCase(id: "3.1", name: "⌘A ⌫", steps: [.shortcut(.maskCommand, "a"), .key(.delete)], expectedText: "вава"),
    BufferResetCase(id: "3.2", name: "⌘A", steps: [.shortcut(.maskCommand, "a")], expectedText: "вава"),
    BufferResetCase(id: "3.2", name: "⌘Z", steps: [.shortcut(.maskCommand, "z")], expectedText: "вава"),
    BufferResetCase(id: "3.2", name: "⌘⌫", steps: [.key(.delete, .maskCommand)], expectedText: "вава"),
    BufferResetCase(id: "3.2", name: "⌃A", steps: [.shortcut(.maskControl, "a")], expectedText: "ваваghbdtn"),
    BufferResetCase(id: "4.1", name: "← →", steps: [.key(.left), .key(.right)], expectedText: "ghbdtnвава"),
    BufferResetCase(id: "4.2", name: "Home End", steps: [.key(.home), .key(.end)], expectedText: "ghbdtnвава"),
    BufferResetCase(id: "4.2", name: "PgUp PgDn", steps: [.key(.pageUp), .key(.pageDown)], expectedText: "ghbdtnвава"),
    BufferResetCase(id: "4.2", name: "⌦", steps: [.key(.forwardDelete)], expectedText: "ghbdtnвава"),
    BufferResetCase(id: "4.2", name: "Return", steps: [.key(.returnKey)], expectedText: "ghbdtn\nвава"),
    BufferResetCase(id: "4.2", name: "F5", steps: [.key(.f5)], expectedText: "ghbdtnвава"),
]
