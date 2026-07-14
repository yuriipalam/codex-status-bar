# Changelog

All notable changes to Codex Status Bar are documented here.

## 0.3.0 - 2026-07-14

### Added

- Compact status support for newer local Codex activity, including reasoning, image generation, context compaction, settings changes, and rollbacks.

### Changed

- Classify 5-hour and weekly usage windows by their reported duration instead of assuming fixed primary and secondary positions.
- Correctly display weekly-only limits when Codex reports the weekly window as primary and omits the 5-hour window.
- Show `--` instead of `unavailable` for missing usage percentages, reset times, and snapshots.
- Keep unknown incoming activity types ignored so they do not overwrite the last recognized status.

## 0.2.0 - 2026-07-08

### Added

- Homebrew formula installation that builds Codex Status Bar from source.
- Start at login menu item.

### Changed

- Added DMG Gatekeeper unblock instructions for non-notarized downloads.
- Added the Homebrew trust step required for the current custom tap.
- Disabled SwiftPM's nested sandbox during Homebrew formula builds.
- Grouped display toggles under an Options submenu, with Color and Animation as top-level menu controls.
- Enabled Start at login by default on first launch while preserving the user's later toggle choice.
- Documented Homebrew update, uninstall, and saved-settings cleanup commands.
- Show Idle when both usage windows are hidden and there is no active or unread Codex activity.
- Use a native AppKit badge control for session client badges so APP, CLI, and IDE labels align consistently.

## 0.1.1 - 2026-07-05

### Added

- Product-first README with DMG installation instructions.
- Contributor guide with build and packaging details.
- Acknowledgement for the Claude Status Bar project that inspired this app.

### Changed

- Renamed the product and release artifacts to Codex Status Bar, `CodexStatusBar.app`, and `CodexStatusBar.dmg`.
- Replaced the app icon with a generated raster icon and build the `.icns` from `CodexBarAppIcon.png`.
- Simplified privacy, behavior, and packaging copy for readers who just want to install the app.

## 0.1.0 - 2026-07-03

### Added

- Initial native macOS menu bar app for local Codex activity.
- Local status display for thinking, working, tool use, waiting for input, awaiting approval, unread sessions, and idle usage snapshots.
- Menu controls for timer display, local usage windows, icon color, animation style, session rows, and app version.
- Read-only local parsing of Codex session JSONL and unread-thread state.
- Source build and local DMG packaging scripts.
