# Flipio end-to-end tests

Automated tests (Swift Testing, run with `swift test`; XCUITest cannot post the HID-level Option taps and layout switches Flipio reacts to) that drive real apps with real keystrokes and check what actually ends up on screen. They cover cases from [TEST_PLAN.md](../TEST_PLAN.md); each test name starts with the plan's case ID.

Currently automated (VS Code editor): **1.1–1.4** and **2.1** (repeated 10 times).

## Requirements

- macOS 14+, Xcode with Swift 6 (for Swift Testing).
- Visual Studio Code installed.
- Exactly two keyboard layouts enabled: **U.S.** (or ABC) and **Russian**.
- **Select the previous input source** shortcut enabled (System Settings → Keyboard → Keyboard Shortcuts → Input Sources).
- Caps Lock off.
- **Accessibility** permission for the app you run the tests from (Terminal, iTerm, or VS Code if you use its integrated terminal), and for the Flipio build under test. A Debug build at a new path needs its own grant.

These are checked at start (see `Preflight.swift`). If any fails, the problems are printed and the tests are skipped.

## Running

```sh
cd E2ETests
./run.sh                          # build Flipio (Debug), run everything
./run.sh --filter "1.1"           # a single case
FLIPIO_APP=/Applications/Flipio.app ./run.sh   # test an existing build
```

`run.sh`:

1. Builds Flipio Debug into `.run/DerivedData` (skipped with `FLIPIO_APP`).
2. Restarts Flipio with `-TestHooksEnabled YES`.
3. Runs `swift test --no-parallel`.
4. Stops the test Flipio and restarts the Flipio you were running before.

**While it runs, it takes over the keyboard and focus.** Do not touch the keyboard or mouse until it finishes.

## How it works

- **Keystrokes** are posted at the HID level as key presses on the U.S. layout (`Keyboard.swift`), so the characters depend on the active layout, as with real typing. ⌥ taps are a real Option press and release.
- **Flipio signals**: when started with `-TestHooksEnabled YES`, Flipio posts Darwin notifications (`App/TestHooks.swift`) when a conversion finishes and when the layout switch has been verified (`confirmed`, `fallback`, `skipped`, …, plus how many times the ⌃Space shortcut was pressed). Tests wait for these instead of sleeping.
- **VS Code**: each test launches a new instance with a temporary profile (settings from `Fixtures/vscode/settings.json`: suggestions, auto-closing and formatting off) and types into its untitled editor. Nothing is saved. The text is read through the clipboard (⌘A, ⌘C; the clipboard is restored). The instance is targeted by process ID and killed when the test ends, so the VS Code you work in is never touched.
- **Diagnostics** come from the test framework: failed `#expect`s show the actual values, and preflight problems are logged via `os.Logger` (subsystem `com.flipio.e2e`) and shown as the reason tests were skipped.

## Layout

```
Package.swift
run.sh
Fixtures/vscode/settings.json
Sources/E2EKit/Support/            Keyboard, InputSource, FlipioProbe, Preflight, Waiting
Sources/E2EKit/Screens/            page objects: VSCodeScreen (launch, reset, text, close)
Tests/FlipioE2ETests/Support/      shared tags and the inFreshEditor helper
Tests/FlipioE2ETests/Tests/        VSCodeBasicTests
```

## Adding tests

- New cases for an existing app: add a `@Test` (or an argument to a parameterized one) in the app's suite. Always await `awaitLayoutVerified()` after a conversion so a pending layout check cannot leak into the next test.
- New apps: add a page object in `Screens/` like `VSCodeScreen` (launch, `reset`, `text`, `close`) and a suite in `Tests/`.

## Limits

- Synthetic keystrokes may not reproduce timing that only happens with a physical keyboard; keep one manual run of 2.1 per machine.
- The "Automatically switch to a document's input source" setting is not read; set it by hand for cases that depend on it.
