# Flipio end-to-end tests

Automated tests (Swift Testing, run with `swift test`; XCUITest cannot post the HID-level Option taps and layout switches Flipio reacts to) that drive real apps with real keystrokes and check what actually ends up on screen. They cover cases from [TEST_PLAN.md](TEST_PLAN.md); each test name starts with the plan's case ID.

Currently automated — TextEdit: **1.1–1.4**, **2.1–2.3**, **3.1–3.3** (3.2 without ⌥⌫), **4.1**, **4.2** (arrows, Home/End, PgUp/PgDn, ⌦, Return, F5), **5.1**, **6.1–6.4**; Spotlight: **7.1**; Chrome: **7.2**, **7.3**; OneNote (your running copy): **7.5**; VS Code (Chromium/Electron smoke check): **1.1–1.3**. 2.3 needs System Settings → Keyboard → Text Input → Edit → **Automatically switch to a document's input source** on. Each scenario runs once, with no automatic retries.

## Requirements

- macOS 14+, Xcode with Swift 6 (for Swift Testing).
- Visual Studio Code, Google Chrome and Microsoft OneNote installed; ⌘Space opens Spotlight.
- Exactly two keyboard layouts enabled: **U.S.** (or ABC) and **Russian**.
- **Select the previous input source** shortcut enabled (System Settings → Keyboard → Keyboard Shortcuts → Input Sources).
- Caps Lock off.
- **Accessibility** permission for the app you run the tests from (Terminal, iTerm, or VS Code if you use its integrated terminal), and for the Flipio build under test. A Debug build at a new path needs its own grant (Flipio asks on launch). `run.sh` prompts for the terminal's permission and opens the settings pane if it is missing; enable the terminal there and re-run.

These are checked at start (see `Preflight.swift`). If any fails, the problems are printed and the tests are skipped.

The Flipio build must include the current test hooks. Preflight verifies a live readiness state containing the app's PID, not just its launch arguments. An older installed build can convert text but cannot signal completion to the tests. In that case, run `./run.sh` without `FLIPIO_APP` to build the current sources, or rebuild and install Flipio first.

## Running

```sh
cd E2ETests
./run.sh                          # build Flipio (Debug), run everything
./run.sh --filter "quickTyping"     # a single test, by function name (not its display name)
./run.sh --filter "TextEditBasicTests"   # one suite
FLIPIO_APP=/Applications/Flipio.app ./run.sh   # test an existing build
./run.sh --dont-quit-flipio           # leave Flipio running after the suite
```

`run.sh`:

1. Builds Flipio Debug into `.run/DerivedData` (skipped with `FLIPIO_APP`) and re-signs it with the `Flipio Self-Signed` release certificate when it is in your keychain (import `flipio-signing.p12` once), so macOS reuses the Accessibility permission of the installed release Flipio. Without the certificate the Xcode signature is kept and macOS asks for the permission once.
2. Restarts Flipio with `-TestHooksEnabled YES`.
3. Runs `swift test --no-parallel --disable-xctest --maximum-repetitions 1`.
4. Stops the test Flipio and restarts the Flipio you were running before.

**While it runs, it takes over the keyboard and focus.** Do not touch the keyboard or mouse until it finishes.

## OneNote

OneNote cannot be a throw-away instance, so the 7.5 test types into your running copy. It fails unless the **Test Sandbox** page is open (found as the selected entry in the page list): open that page (Flipio section) and put the cursor in the page body first. The page body is cleared before and after the test. Turn off OneNote's auto-capitalization if `hello` becomes `Hello`.

## How it works

- **Keystrokes** are posted at the HID level as key presses on the U.S. layout (`Keyboard.swift`), so the characters depend on the active layout, as with real typing. ⌥ taps are a real Option press and release.
- **Flipio signals**: when started with `-TestHooksEnabled YES`, Flipio posts Darwin notifications (`App/TestHooks.swift`) when a conversion finishes and when the layout switch has been verified (`confirmed`, `fallback`, `skipped`, …, plus how many times the ⌃Space shortcut was pressed). Tests wait for these instead of sleeping.
- **TextEdit**: each test opens an empty `.txt` file from a temporary directory in a new TextEdit instance (`createsNewApplicationInstance`), so it is plain text and the TextEdit you work in is untouched. Launch arguments turn off window restoration, autocorrection, auto-capitalization and smart substitutions for that instance only. The text is read through the clipboard like VS Code; the instance is killed by PID and the directory removed when the test ends.
- **VS Code**: each test launches a new instance asynchronously through `NSWorkspace`, with a temporary profile (settings from `Fixtures/vscode/settings.json`: suggestions, auto-closing and formatting off), and types into its untitled editor. Nothing is saved. The text is read through the clipboard (⌘A, ⌘C; the clipboard is restored). The instance is targeted by the PID returned by macOS and killed when the test ends, so the VS Code you work in is never touched. Startup failures report launch errors, early termination, or the last Accessibility window-query result; the temporary profile is retained at the reported path for inspection of VS Code's logs under `data/logs/`.
- **Profile paths** use a short, uniquely created `flipio-XXXXXX` directory in the system temporary directory. Keep this name short: VS Code creates `data/<version>-main.sock` inside it, and macOS limits Unix-domain socket paths to 103 bytes. A long profile path can make VS Code exit before opening a window or writing its startup log.
- **Diagnostics** come from the test framework: failed `#expect`s show the actual values, and preflight problems are logged via `os.Logger` (subsystem `com.flipio.e2e`) and shown as the reason tests were skipped.

## Layout

```
Package.swift
run.sh
Fixtures/vscode/settings.json
Sources/E2EKit/Support/            Keyboard, InputSource, FlipioProbe, Preflight, Waiting
Sources/E2EKit/Screens/            page objects: EditorScreen protocol (with, reset, text), VSCodeScreen, TextEditScreen
Tests/FlipioE2ETests/Support/      shared tags, conversion cases, inFreshEditor and checkConversion helpers
Tests/FlipioE2ETests/Tests/        VSCodeBasicTests, TextEditBasicTests
```

## Adding tests

- New cases for an existing app: add a `@Test` (or an argument to a parameterized one) in the app's suite. Always await `awaitLayoutVerified()` after a conversion so a pending layout check cannot leak into the next test.
- New apps: add a page object in `Screens/` conforming to `EditorScreen` (`launch`, `close`; `reset` and `text` come from the protocol) and a suite in `Tests/`. Reuse `basicConversionCases` with `checkConversion` for the basic cases.

## Limits

- Synthetic keystrokes may not reproduce timing that only happens with a physical keyboard; keep one manual run of 2.1 per machine.
- The "Automatically switch to a document's input source" setting is not read; set it by hand for cases that depend on it.
