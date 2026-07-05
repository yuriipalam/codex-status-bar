# Changelog

All notable changes to Codex Status Bar are documented here.

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
