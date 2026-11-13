# Sparkle Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flipio checks for updates in the background (switchable off), installs them via Sparkle, and offers a manual "Check for Updates…".

**Architecture:** Sparkle 2 (`SPUStandardUpdaterController`) wrapped in an `UpdateManager`. UI hooks in the menu bar menu and Settings. CI signs each DMG with an EdDSA key and publishes `appcast.xml` as a release asset; the app reads it from `releases/latest/download/`.

**Tech Stack:** Swift/SwiftUI/AppKit, Sparkle 2.x via SwiftPM, GitHub Actions, Homebrew cask.

**Spec:** [docs/superpowers/specs/2026-11-13-sparkle-autoupdate-design.md](../specs/2026-11-13-sparkle-autoupdate-design.md)

## Global Constraints

- Feed URL: `https://github.com/pggolub/flipio/releases/latest/download/appcast.xml`
- No Apple Developer Program / notarization; builds stay ad-hoc signed (`CODE_SIGN_IDENTITY=-`).
- `SUSendSystemProfile` = NO. Toggle default on; off = no background network calls; manual check always works.
- Release builds are unsandboxed (`ENABLE_APP_SANDBOX=NO`); do not add Sparkle sandbox XPC services.
- Pre-release tags (containing `-`) must not be published as the "latest" feed.
- Deployment target macOS 14.0. Build number (`CFBundleVersion`) = `github.run_number`.
- Homebrew cask gets `auto_updates true`.
- The repo has no test target; verification is build success plus the manual checks stated per task. Do not add a test target.

## Review Focus

- Accessibility permission re-prompt after a self-update (ad-hoc binary identity changes): measure in Task 5, document the result.
- Update check with no network / feed 404 (e.g. a release without `appcast.xml`): app must show Sparkle's normal error, never crash or hang the menu.
- Toggle off, then relaunch: it must stay off and make no background request.
- Manual check clicked twice quickly / while a check runs: item disabled, no second dialog.
- Update dialog appearing behind other windows for this `LSUIElement` app: must come to front.

---

### Task 1: Add Sparkle and UpdateManager

**Files:**
- Modify: `Flipio.xcodeproj/project.pbxproj` (add SwiftPM dependency `https://github.com/sparkle-project/Sparkle`, up to next major from 2.6.0, product `Sparkle` linked to the Flipio target)
- Create: `App/UpdateManager.swift`
- Create: `App/Info.plist` (partial; merged with generated plist) and set `INFOPLIST_FILE = App/Info.plist` in both build configurations (keep `GENERATE_INFOPLIST_FILE = YES`)
- Modify: `App/AppDelegate.swift`

**Interfaces:**
- Produces:
  - `@MainActor final class UpdateManager: NSObject, ObservableObject` with `static let shared: UpdateManager`
  - `@Published private(set) var canCheckForUpdates: Bool`
  - `var automaticallyChecksForUpdates: Bool { get set }` (reads/writes `updater.automaticallyChecksForUpdates`; must `objectWillChange.send()` on set)
  - `func checkForUpdates()`
- Consumes: nothing.

- [ ] **Step 1:** Add the package dependency in Xcode (File ▸ Add Package Dependencies) so `project.pbxproj` and `Package.resolved` are updated correctly. Do not hand-edit the pbxproj.
- [ ] **Step 2:** Create `App/Info.plist` with `SUFeedURL` (value from Global Constraints), `SUPublicEDKey` (placeholder string `REPLACE_WITH_PUBLIC_KEY` until Task 4 step 1), `SUSendSystemProfile` = false, `SUEnableAutomaticChecks` = true (first-run default; Sparkle then persists the user's choice).
- [ ] **Step 3:** Implement `UpdateManager` as specified in Interfaces. Wrap `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)`; mirror `updater.publisher(for: \.canCheckForUpdates)` into `canCheckForUpdates` via Combine. Add an `SPUUpdaterDelegate` method or pre-call `NSApp.activate(ignoringOtherApps: true)` in `checkForUpdates()` so the dialog is frontmost.
- [ ] **Step 4:** In `AppDelegate.applicationDidFinishLaunching`, touch `UpdateManager.shared` before `setupMenu()` so the updater starts at launch.
- [ ] **Step 5: Verify:** `xcodebuild -project Flipio.xcodeproj -scheme Flipio -configuration Debug build` succeeds; launching the app produces no Sparkle error about a missing feed/key in Console (a "no valid signature" error later is expected until Task 4).
- [ ] **Step 6: Commit** — `git commit -m "Add Sparkle and UpdateManager"`

### Task 2: Menu bar "Check for Updates…"

**Files:**
- Modify: `App/AppDelegate.swift` (`setupMenu`, around lines 33-56)

**Interfaces:**
- Consumes: `UpdateManager.shared.checkForUpdates()`, `canCheckForUpdates`.

- [ ] **Step 1:** Add menu item titled `Check for Updates…` between Settings and the separator, action `@objc private func checkForUpdates()` calling `UpdateManager.shared.checkForUpdates()`.
- [ ] **Step 2:** Make it disable while checking: have `AppDelegate` conform to `NSMenuItemValidation` and return `UpdateManager.shared.canCheckForUpdates` for that item's action (menus are validated on open, so no observation needed).
- [ ] **Step 3: Verify (manual):** run the app, open the menu bar menu, item present; click it with the placeholder key and observe Sparkle shows a result/error dialog in front of other windows, and the item is greyed while the dialog is mid-check.
- [ ] **Step 4: Commit** — `git commit -m "Add Check for Updates menu item"`

### Task 3: Settings toggle and button

**Files:**
- Modify: `App/Views/SettingsWindow.swift` (General section, after the "Paste without formatting" row, ~line 95)

**Interfaces:**
- Consumes: `UpdateManager.shared` (`@ObservedObject`), `automaticallyChecksForUpdates`, `canCheckForUpdates`, `checkForUpdates()`.

- [ ] **Step 1:** Add `@ObservedObject private var updateManager = UpdateManager.shared` to `SettingsWindow`.
- [ ] **Step 2:** Add a row matching the existing row style (13pt title, 11pt secondary caption, switch toggle, `.focusable(false)`): title `Automatically check for updates`, caption `Flipio checks for new versions in the background.`, bound to `Binding(get: { updateManager.automaticallyChecksForUpdates }, set: { updateManager.automaticallyChecksForUpdates = $0 })`.
- [ ] **Step 3:** Add a second row with a `Check for Updates…` button (`.disabled(!updateManager.canCheckForUpdates)`) and a caption `Version \(Self.appVersion)`.
- [ ] **Step 4:** Window height is fixed at 600 with `scrollDisabled(true)`; confirm both new rows fit, raising the minimum height in `SettingsWindow` and `AppDelegate.openPrefs` only if they clip.
- [ ] **Step 5: Verify (manual):** toggle off, quit, relaunch → toggle still off (`defaults read com.flipio.app SUEnableAutomaticChecks` is 0 or `SUAutomaticallyUpdate` state persists); with it off, a manual check still works. Toggle on and the checked state survives relaunch.
- [ ] **Step 6: Commit** — `git commit -m "Add auto-update toggle and manual check in Settings"`

### Task 4: Release pipeline (signing + appcast)

**Files:**
- Modify: `.github/workflows/release.yml` (job `release`, after "Package DMG", before "Publish GitHub release")
- Modify: `App/Info.plist` (real `SUPublicEDKey`)
- Modify: `README.md` (short "Updates" section)

**Interfaces:**
- Consumes: GitHub secret `SPARKLE_ED_PRIVATE_KEY`.
- Produces: release asset `appcast.xml` whose single `<item>` has `sparkle:version` = run number, `sparkle:shortVersionString` = `$VERSION`, enclosure URL `https://github.com/pggolub/flipio/releases/download/v$VERSION/Flipio-$VERSION.dmg`, `sparkle:edSignature`, `length`.

- [ ] **Step 1 (manual, by the user):** download a Sparkle release, run `bin/generate_keys` once, copy the public key into `App/Info.plist`, and store the private key (from `generate_keys -x`) as the repo secret `SPARKLE_ED_PRIVATE_KEY`. Plan executor: stop and ask the user to do this; never generate or print the private key in the session.
- [ ] **Step 2:** Add workflow steps: download a pinned Sparkle release archive (same version as the SwiftPM pin) to get `sign_update`; run `sign_update --ed-key-file - Flipio-$VERSION.dmg` with the secret piped on stdin; write `appcast.xml` from that output with a short shell heredoc. Skip appcast generation when `$GITHUB_REF_NAME` contains `-`, and mark pre-release tags as `prerelease: true` on `softprops/action-gh-release` so `latest` does not move.
- [ ] **Step 3:** Add `appcast.xml` to the `files:` list of the publish step.
- [ ] **Step 4:** Add a CI check after "Ad-hoc codesign" that the embedded `Sparkle.framework` is covered: `codesign --verify --deep --strict build/export/Flipio.app`.
- [ ] **Step 5: Verify:** push a pre-release tag (e.g. `v1.1.0-rc1`) → workflow green, release is marked pre-release, no `appcast.xml`. Then see Task 5 for the stable run.
- [ ] **Step 6: Commit** — `git commit -m "Sign releases and publish Sparkle appcast"`

### Task 5: Cask change and end-to-end update test

**Files:**
- Modify: `/Users/Pavel_Golub/work/homebrew-flipio/Casks/flipio.rb` (add `auto_updates true` after `desc`/`homepage`, per `brew style` ordering)
- Modify: `CHANGELOG.md`

- [ ] **Step 1:** Add `auto_updates true`; run `brew style --cask` and `brew audit --cask --online pggolub/flipio/flipio` locally and confirm both pass. Commit in the tap repo only when the user asks (the release workflow also pushes there).
- [ ] **Step 2 (end-to-end):** release `v1.1.0` (first Sparkle build) and install it. Then release `v1.1.1` and, in the installed 1.1.0, click Check for Updates….
  Expected: dialog offers 1.1.1, installs, relaunches, About shows 1.1.1, app launches without a Gatekeeper block.
- [ ] **Step 3:** After the update, check whether Accessibility permission was revoked or re-prompted. Record the result in `CHANGELOG.md` and tell the user; if it re-prompts, stop and discuss a stable signing identity before declaring done.
- [ ] **Step 4:** Test failure path: temporarily point `SUFeedURL` at a 404 URL in a Debug build; the check shows Sparkle's error dialog and the menu item re-enables.
- [ ] **Step 5: Commit** — `git commit -m "Document auto-update behavior"`
