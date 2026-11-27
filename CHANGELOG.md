# Changelog

All notable changes to Flipio are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project uses [semantic versioning](https://semver.org/).

## [Unreleased]

## [1.3.0] - 2026-11-27

### Added
- Automatic updates via Sparkle: "Automatically check for updates" toggle and "Check for Updates…" in the menu bar menu.

### Fixed
- Accessibility permission was lost after every update because releases were ad-hoc signed. Releases are now signed with a stable self-signed certificate. Users must re-grant the permission once (remove Flipio with **−** in System Settings ▸ Privacy & Security ▸ Accessibility, then add it again with **+**).
- Layout sometimes switched back to the original one right after conversion. The simulated ⌃Space shortcut now releases Control after Space (as a person does), and the switch is verified afterwards: a reverted switch is retried once, and the layout is selected directly if the shortcut lands elsewhere.
- Conversion could retype old, already-deleted text (e.g. after ⌘A + ⌫). The typed-word buffer now resets on any ⌘/⌃/⌥ key combination and on navigation, function and media keys.

### Notes
- Versions up to 1.0.7 have no updater; install the first Sparkle release manually (or via `brew upgrade`).
- Self-updated ad-hoc signed builds may need Accessibility permission re-granted; result of the real update test to be recorded here.

## [1.0.4] - 2026-04-24

First stable release.

## [0.1.0-beta] - 2026-04-20

First public beta. Distributed via Homebrew cask (`pggolub/flipio` tap).

### Added
- Menu bar app that converts selected text or the last typed word between keyboard layouts on Option-tap.
- Bidirectional detection (e.g. English ↔ Russian).
- Selection mode and typed-word mode.
- Launch-at-login option.

### Notes
- Bundle identifier: `com.flipio.app`.
- Ad-hoc signed (author is not in the Apple Developer Program). The cask removes the Gatekeeper quarantine attribute after installation.
- Requires macOS 14.0 (Sonoma) or later.
- Requires Accessibility permission; grant it in System Settings → Privacy & Security → Accessibility or at first app start.
