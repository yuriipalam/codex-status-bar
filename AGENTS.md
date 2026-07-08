# Repository Instructions

Read `README.md` before making changes. Follow the product behavior, privacy boundaries, build commands, distribution notes, and local-state assumptions documented there.

## Engineering Expectations

- Prefer the existing SwiftPM layout: keep platform-independent parsing, state, formatting, and presentation logic in `Sources/CodexBarCore`, and keep AppKit/menu-bar wiring in `Sources/CodexBar`.
- Use Swift and macOS best practices for a small native menu-bar app: value types for pure model/presentation state, dependency injection for filesystem/environment readers, main-thread AppKit updates, and no unnecessary global state.
- Keep Codex Status Bar local-first and read-only for Codex activity data. Do not add network calls, telemetry, hooks, or writes to session JSONL/global state.
- Treat Codex local files as implementation details, not a stable public API. Add or update focused tests when parsing new JSONL events, state files, metadata fields, or status labels.
- Use `originator` only for visible `APP`/`CLI`/`IDE` client badges. Do not fall back to noisy `source` metadata for badge display.
- For shell scripts, fail fast on errors, quote paths, avoid destructive commands, and keep release packaging reproducible from `./build.sh --dmg`.
- For release packaging, assemble, sign, and verify the app in a clean staging directory, then publish final artifacts into `build/`. In-place local app copies are fine for development, but the DMG should come from the verified staged app.

## Verification

Run the narrowest relevant checks for the change:

```bash
swift test
./build.sh --release
```

For packaging changes, also run:

```bash
./build.sh --dmg
hdiutil verify build/CodexStatusBar.dmg
```

For launch or AppKit behavior changes, run:

```bash
./script/build_and_run.sh --verify
```

Generated build artifacts under `.build/`, `build/`, `dist/`, `.swiftpm/`, and `DerivedData/` should stay untracked.

## Release Procedure

Only the maintainer publishes releases. App bundle versions are controlled by `VERSION` and `BUILD_NUMBER`:

```text
VERSION
BUILD_NUMBER
```

Homebrew also requires a literal package metadata version in `Formula/codex-status-bar.rb`; keep it in sync with `VERSION` during release prep.

Use a patch bump for fixes, docs, packaging, and icon updates; use a minor bump for user-visible features. Keep `BUILD_NUMBER` increasing for every public release.

1. Pick the next version, for example `0.1.1`.
2. Update `VERSION`, `BUILD_NUMBER`, and the `version` field in `Formula/codex-status-bar.rb`.
3. Add or update the relevant `CHANGELOG.md` dated version section, for example `## 0.1.1 - 2026-07-05`.
4. Run:

```bash
swift test
./build.sh --dmg
hdiutil verify build/CodexStatusBar.dmg
```

5. Commit the release prep:

```bash
git add VERSION BUILD_NUMBER CHANGELOG.md
git add Formula/codex-status-bar.rb
git commit -m "chore: release v0.1.1"
git push origin main
```

6. Create and push an annotated tag:

```bash
git tag -a v0.1.1 -m "v0.1.1"
git push origin v0.1.1
```

7. Create the GitHub Release and attach the DMG, using the changelog as the release notes:

```bash
gh release create v0.1.1 build/CodexStatusBar.dmg \
  --repo yuriipalam/codex-status-bar \
  --title "Codex Status Bar 0.1.1" \
  --notes-file CHANGELOG.md
```

The uploaded asset must be named `CodexStatusBar.dmg` so the README download link resolves to the latest release.

Changelog version sections use dates in `YYYY-MM-DD` format.
