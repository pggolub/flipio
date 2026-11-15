# Changelog

All notable changes to Flipio are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project uses [semantic versioning](https://semver.org/).

## [Unreleased]

### Added
- Automatic updates via Sparkle: "Automatically check for updates" toggle and "Check for Updates…" in the menu bar menu.

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
