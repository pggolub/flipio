# Flipio Manual Test Plan

Manual regression scenarios for typed-word conversion. Run them before each release and after changes to [TypedWordBuffer.swift](App/TypedWordBuffer.swift), [TextConversionService.swift](App/TextConversionService.swift), [EventMonitor.swift](App/EventMonitor.swift) or [SystemInputSourceProvider.swift](App/SystemInputSourceProvider.swift).

## Setup

- Input sources: **U.S.** (or ABC) and **Russian** (e.g. Russian – PC). No other keyboard layouts enabled.
- Flipio running with Accessibility permission granted.
- Test app: **TextEdit** (Format → Make Plain Text), new empty document. Repeat key scenarios in one Electron/Chromium app (e.g. VS Code) and one browser text field.
- "Tap ⌥" means press and release Option alone, without any other key.
- Start every scenario with an empty document, the **U.S.** layout active, and the caret at the end of the text.
- To diagnose a failure, stream logs:

  ```sh
  log stream --level debug --predicate 'subsystem == "com.flipio.app"'
  ```

  Each conversion logs `Attempting typed-word conversion for <buffer>`. The buffer must contain only the word that is visible before the caret.

## 1. Basic conversion

| # | Steps | Expected result |
|---|-------|-----------------|
| 1.1 | Type `ghbdtn`, tap ⌥ | Text becomes `привет`; active layout is Russian |
| 1.2 | After 1.1, tap ⌥ again | Text becomes `ghbdtn`; active layout is U.S. |
| 1.3 | Type `hello ghbdtn`, tap ⌥ | Only the last word converts: `hello привет` |
| 1.4 | Type `ghbdtn`, press ⌫ twice, tap ⌥ | Text becomes `прив` (backspace removes one character from the buffer) |

## 2. Layout stays switched after conversion

Regression for the layout reverting to the original one after conversion (see CHANGELOG, Unreleased → Fixed).

| # | Steps | Expected result |
|---|-------|-----------------|
| 2.1 | Type `ghbdtn`, tap ⌥, wait 1 s, type `vbh` | Text is `приветмир`; menu bar shows Russian the whole time |
| 2.2 | Repeat 2.1 typing quickly (no pause after ⌥) | Same as 2.1, no Latin letters appear |

## 3. Buffer resets on shortcuts and modified keys

Regression for conversion retyping old, already-deleted text. Original report: after ⌘A + ⌫, typing `dfdf` and tapping ⌥ produced a long string of old text (`авыфвафывававывафывавыфвсчывафывавфввава`) instead of `вава`.

In every scenario below, the expected log line is `typedBuffer: reset (modifier shortcut)` when the shortcut is pressed, and the next conversion buffer contains only the newly typed word.

| # | Steps | Expected result |
|---|-------|-----------------|
| 3.1 | Type `fdsadfasdfd`, tap ⌥ (→ `авыфвафывав`), switch to U.S., type `asdf`, press **⌘A**, press **⌫**, type `dfdf`, tap ⌥ | Document contains only `вава` |
| 3.2 | Type `ghbdtn`, press **⌘A**, type `dfdf`, tap ⌥ | Document contains only `вава` (typing replaced the selection) |
| 3.3 | Copy `test` to the clipboard. Type `ghbdtn`, press **⌘V**, tap ⌥ | Nothing is retyped from the buffer; Flipio falls back to selection mode (beep if nothing selected). `ghbdtntest` is left unchanged |
| 3.4 | Type `ghbdtn`, press **⌘Z**, type `dfdf`, tap ⌥ | Only `dfdf` converts to `вава`; text restored by undo is untouched |
| 3.5 | Type `hello ghbdtn`, press **⌥⌫** (delete word), type `dfdf`, tap ⌥ | Text becomes `hello вава` |
| 3.6 | Type `hello ghbdtn`, press **⌘⌫** (delete to line start), type `dfdf`, tap ⌥ | Text becomes `вава` |
| 3.7 | Type `ghbdtn`, press **⌃A** (caret to line start), type `dfdf`, tap ⌥ | Text becomes `ваваghbdtn`; only `dfdf` converts |
| 3.8 | Type `ghb`, press **⌥D** (types `∂`), type `dtn`, tap ⌥ | Only `dtn` converts: `ghb∂вен`. An Option-modified character starts a new word |

## 4. Buffer resets on navigation, function and media keys

| # | Steps | Expected result |
|---|-------|-----------------|
| 4.1 | Type `ghbdtn`, press **←**, press **→**, type `dfdf`, tap ⌥ | Text becomes `ghbdtnвава` |
| 4.2 | Repeat 4.1 with **Home/End**, **PgUp/PgDn**, **⌦** (fn⌫) instead of the arrows | Only `dfdf` converts each time |
| 4.3 | Type `ghbdtn`, press **Return**, type `dfdf`, tap ⌥ | First line stays `ghbdtn`; second line becomes `вава` |
| 4.4 | Type `ghbdtn`, press an F-key (e.g. **F5**, or fn+F5 on laptops), type `dfdf`, tap ⌥ | Only `dfdf` converts |
| 4.5 | Type `ghbdtn`, press a media key (volume up/down, mute), type `dfdf`, tap ⌥ | Only `dfdf` converts |
| 4.6 | Type `ghbdtn`, press **fn/Globe** alone, type `dfdf`, tap ⌥ | Only `dfdf` converts |

## 5. Buffer resets on focus and mouse changes

| # | Steps | Expected result |
|---|-------|-----------------|
| 5.1 | Type `ghbdtn`, click somewhere else in the same text, type `dfdf`, tap ⌥ | Only `dfdf` converts |
| 5.2 | Type `ghbdtn` in TextEdit, switch to another app (⌘Tab) and back, type `dfdf`, tap ⌥ | Only `dfdf` converts |
| 5.3 | Type `ghbdtn` in TextEdit, type `dfdf` in another app's text field, tap ⌥ | Only `dfdf` in the second app converts; TextEdit is untouched |

## 6. Negative checks

| # | Steps | Expected result |
|---|-------|-----------------|
| 6.1 | Type `Ghbdtn` using **Shift** for the capital, tap ⌥ | Text becomes `Привет`. Shift alone must not reset the buffer |
| 6.2 | Hold ⌥ for over 1 s and release without other keys | No conversion |
| 6.3 | Press ⌥ together with another key (e.g. ⌥←) | No conversion is triggered by the Option release |
| 6.4 | Empty document, no selection, tap ⌥ | System beep, nothing changes |
| 6.5 | Select `ghbdtn` with the mouse, tap ⌥ | Selection converts to `привет` (selection mode) |
