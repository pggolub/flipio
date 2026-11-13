# Flipio auto-update (Sparkle) — design

## Intent
Users who install Flipio from the DMG have no way to update except re-downloading. Add real in-app updating, with an off switch and a manual check.

## Goals
- Automatic background check for updates, and installation with the standard Sparkle prompt.
- Settings toggle "Automatically check for updates" (default on). Off = no background network calls.
- Manual "Check for Updates…" always works, even with the toggle off. Available in the menu bar menu and in Settings (with current version shown).
- Works with the current ad-hoc-signed, non-notarized distribution.

## Non-goals / anti-goals
- No Apple Developer Program, notarization, or paid infrastructure.
- No custom updater code; no telemetry beyond what Sparkle sends by default (we disable system profiling).
- Must not break Homebrew users (`brew upgrade` keeps working).

## Constraints (found in repo)
- Menu bar app (`LSUIElement`), AppKit status item in `AppDelegate.swift`; settings in SwiftUI `SettingsWindow.swift` with `@AppStorage`/manager-class pattern.
- Release workflow (`.github/workflows/release.yml`) builds unsandboxed, ad-hoc signs with `codesign --deep`, packages DMG, publishes GitHub release, then bumps the Homebrew cask.
- Version comes from the git tag (`agvtool`), build number from `github.run_number` (monotonic, suitable for `CFBundleVersion` comparison).

## Approaches considered
1. **Sparkle 2 (chosen):** full auto-install, EdDSA-verified, no Apple account needed. Cost: dependency + signing step + appcast.
2. Custom GitHub-API checker: small, but cannot install; fails the "autoupdate" goal.
3. Hybrid (custom for brew, Sparkle for DMG): two code paths, overkill.

## Design
**App**
- Add Sparkle via Swift Package Manager. Own the `SPUStandardUpdaterController` in a small `UpdateManager` (ObservableObject), created at launch.
- Info.plist keys: `SUFeedURL` (https://github.com/pggolub/flipio/releases/latest/download/appcast.xml), `SUPublicEDKey`, `SUEnableAutomaticChecks` unset (we drive it from the toggle), `SUSendSystemProfile` = NO.
- Toggle binds to `updater.automaticallyChecksForUpdates` (Sparkle persists it in UserDefaults). Default on at first run.
- "Check for Updates…" menu item and Settings button call `checkForUpdates`, disabled while a check is in progress (`canCheckForUpdates`).
- Because the app is an accessory app, bring the update dialog to the front when it appears.

**Release pipeline**
- One-time: generate an EdDSA key pair with Sparkle's `generate_keys`; public key goes in Info.plist, private key in a GitHub secret (`SPARKLE_ED_PRIVATE_KEY`).
- After packaging the DMG: run `sign_update` on it, generate `appcast.xml` (version, build number, DMG URL, signature, length, release notes link), upload it as a release asset next to the DMG. The `latest/download/` URL always serves the newest stable release.
- Pre-release tags (containing `-`) must not become the "latest" feed.
- Embedded Sparkle framework and helpers must be covered by the existing ad-hoc `codesign --deep` step; verify in CI.

**Homebrew**
- Add `auto_updates true` to the cask so `brew upgrade` skips Flipio unless `--greedy`, avoiding version conflicts. Cask still updates for fresh installs.

## First-update caveat
Versions already installed (≤1.0.7) have no updater. The first Sparkle-enabled release must be installed manually (or via brew); auto-update works from the release after that.

## Risks to verify early (builder)
- Ad-hoc signed app replacing itself via Sparkle: confirm the install step succeeds and Gatekeeper does not block the relaunched app (the cask currently strips quarantine; Sparkle downloads are not quarantined, but test).
- Accessibility permission: a replaced ad-hoc binary has a new code identity, so macOS may re-prompt for Accessibility after each update. This is the biggest user-facing risk; measure it before shipping, and if it happens, note it in release notes / consider a stable signing identity.
- Sandbox: Xcode default build has `ENABLE_APP_SANDBOX=YES`; release is unsandboxed. Keep Sparkle's sandbox XPC services out of scope.

## Left to the builder
Exact UI layout of the Settings row, appcast generation script details, release-notes source (GitHub auto-generated notes link is the default), test strategy.
