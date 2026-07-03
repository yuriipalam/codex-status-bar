# Repository Instructions

Read `README.md` before making changes. Follow the product behavior, privacy boundaries, build commands, distribution notes, and local-state assumptions documented there.

## Engineering Expectations

- Prefer the existing SwiftPM layout: keep platform-independent parsing, state, formatting, and presentation logic in `Sources/CodexBarCore`, and keep AppKit/menu-bar wiring in `Sources/CodexBar`.
- Use Swift and macOS best practices for a small native menu-bar app: value types for pure model/presentation state, dependency injection for filesystem/environment readers, main-thread AppKit updates, and no unnecessary global state.
- Keep Codex Bar local-first and read-only for Codex activity data. Do not add network calls, telemetry, hooks, or writes to session JSONL/global state.
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
hdiutil verify build/CodexBar.dmg
```

For launch or AppKit behavior changes, run:

```bash
./script/build_and_run.sh --verify
```

Generated build artifacts under `.build/`, `build/`, `dist/`, `.swiftpm/`, and `DerivedData/` should stay untracked.
