# Flipio Manual Test Plan

Manual regression scenarios for typed-word conversion. Run them before each release and after changes to [TypedWordBuffer.swift](../App/TypedWordBuffer.swift), [TextConversionService.swift](../App/TextConversionService.swift), [EventMonitor.swift](../App/EventMonitor.swift) or [SystemInputSourceProvider.swift](../App/SystemInputSourceProvider.swift).

Cases marked **S** in the *Smoke* column form the smoke suite: run it on every build; run the full plan before each release.

Most cases are automated in [the E2E tests](README.md) (`run.sh`); see its README for the list and the exceptions (4.2 media keys and fn/Globe, the 3.2 ⌥⌫ variant, 3.4, the beep in 6.3).

## Setup

- Input sources: **U.S.** (or ABC) and **Russian** (e.g. Russian – PC). No other keyboard layouts enabled.
- Flipio running with Accessibility permission granted.
- Test app: **TextEdit** (Format → Make Plain Text), new empty document. App-specific cases are in section 7.
- "Tap ⌥" means press and release Option alone, without any other key.
- Start every scenario with an empty document, the **U.S.** layout active, and the caret at the end of the text.
- To diagnose a failure, stream logs:

  ```sh
  log stream --level debug --predicate 'subsystem == "com.flipio.app"'
  ```

  Each conversion logs `Attempting typed-word conversion for <buffer>`. The buffer must contain only the word that is visible before the caret.

## 1. Basic conversion

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 1.1 | S | Type `ghbdtn`, tap ⌥ | Text becomes `привет`; active layout is Russian |
| 1.2 | S | After 1.1, tap ⌥ again | Text becomes `ghbdtn`; active layout is U.S. |
| 1.3 | S | Type `hello ghbdtn`, tap ⌥ | Only the last word converts: `hello привет` |
| 1.4 | | Type `ghbdtn`, press ⌫ twice, tap ⌥ | Text becomes `прив` (backspace removes one character from the buffer) |

## 2. Layout stays switched after conversion

Regression for the layout reverting to the original one after conversion (see CHANGELOG, Unreleased → Fixed).

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 2.1 | S | Type `ghbdtn`, tap ⌥, wait 1 s, type `vbh` | Text is `приветмир`; menu bar shows Russian the whole time |
| 2.2 | | Repeat 2.1 typing quickly (no pause after ⌥) | Same as 2.1, no Latin letters appear |
| 2.3 | | In System Settings → Keyboard → Text Input → Edit, turn on **Automatically switch to a document's input source**. Type `ghbdtn`, tap ⌥, wait 1 s, switch to another app (⌘Tab) and back to the same TextEdit document, type `vbh` | Text is `приветмир`; layout is still Russian after returning, without any extra key presses. Log shows `activateInputSource: '…Russian…' confirmed` |

## 3. Buffer resets on shortcuts and modified keys

Regression for conversion retyping old, already-deleted text. Original report: after ⌘A + ⌫, typing `dfdf` and tapping ⌥ produced a long string of old text (`авыфвафывававывафывавыфвсчывафывавфввава`) instead of `вава`.

For 3.1 and 3.2 the expected log line is `typedBuffer: reset (modifier shortcut)` when the shortcut is pressed, and the next conversion buffer contains only the newly typed word.

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 3.1 | S | Type `ghbdtn`, press **⌘A**, press **⌫**, type `dfdf`, tap ⌥ | Document contains only `вава` |
| 3.2 | | Repeat 3.1, replacing **⌘A ⌫** with each of: **⌘A** alone (typing replaces the selection), **⌘Z**, **⌥⌫**, **⌘⌫**, **⌃A** | Only `dfdf` converts to `вава`; nothing else is retyped (with ⌃A the text is `ваваghbdtn`) |
| 3.3 | | Copy `test` to the clipboard. Type `ghbdtn`, press **⌘V**, tap ⌥ | Nothing is retyped from the buffer; Flipio falls back to selection mode (beep if nothing selected). `ghbdtntest` is left unchanged |
| 3.4 | | Type `ghb`, press **⌥D** (types `∂`), type `dtn`, tap ⌥ | Only `dtn` converts: `ghb∂вет`. An Option-modified character starts a new word |

## 4. Buffer resets on navigation, function and media keys

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 4.1 | S | Type `ghbdtn`, press **←**, press **→**, type `dfdf`, tap ⌥ | Text becomes `ghbdtnвава` |
| 4.2 | | Repeat 4.1, replacing the arrows with each of: **Home/End**, **PgUp/PgDn**, **⌦** (fn⌫), **Return**, an F-key (**F5** or fn+F5), a media key (volume, mute), **fn/Globe** alone | Only `dfdf` converts each time |

## 5. Buffer resets on focus and mouse changes

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 5.1 | S | Type `ghbdtn`, click somewhere else in the same text, type `dfdf`, tap ⌥ | Only `dfdf` converts |

## 6. Negative checks

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 6.1 | | Type `Ghbdtn` using **Shift** for the capital, tap ⌥ | Text becomes `Привет`. Shift alone must not reset the buffer |
| 6.2 | | Type `ghbdtn`. Hold ⌥ for over 1 s and release; then press ⌥← | No conversion in either case |
| 6.3 | | Empty document, no selection, tap ⌥ | System beep, nothing changes |
| 6.4 | S | Select `ghbdtn` with the mouse, tap ⌥ | Selection converts to `привет` (selection mode) |

## 7. App-specific deletion strategies

Flipio deletes the typed word differently in some apps (see `deleteTypedText` in [TextConversionService.swift](../App/TextConversionService.swift)). A failure usually shows up as leftover characters, an extra space, or the replacement typed next to the original word. Using `hello ghbdtn` checks both directions: too few deletions leave Latin letters, too many damage `hello`.

| # | Smoke | Steps | Expected result |
|---|-------|-------|-----------------|
| 7.1 | S | **Spotlight**: press ⌘Space, type `hello ghbdtn`, tap ⌥, then tap ⌥ again | Search field contains exactly `hello привет`, then `hello ghbdtn`; results update each time. Log shows `deleteTypedText: using Control+Backspace for Spotlight` |
| 7.2 | | **Chrome** address bar: click it, type `ghbdtn`, tap ⌥ | Address bar contains exactly `привет` with no trailing space; no autocomplete suggestion is accepted. Log shows `deleteTypedText: using Space then backspace for com.google.Chrome` |
| 7.3 | S | **Chrome** page text field (e.g. a search box on a web page): type `hello ghbdtn`, tap ⌥, then tap ⌥ again | Field contains exactly `hello привет`, then `hello ghbdtn`, with no extra space |
| 7.5 | S | **OneNote**: in a page, type `hello ghbdtn`, tap ⌥, then tap ⌥ again | Page contains exactly `hello привет`, then `hello ghbdtn`; no text is left selected. Log shows `deleteTypedText: using select-and-delete for com.microsoft.onenote.mac` |
