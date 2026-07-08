# Contributing

Thanks for helping improve Codex Status Bar. Keep the app local-first, read-only for Codex activity data, and small enough to remain easy to inspect.

## Development

```bash
swift test
./script/build_and_run.sh --verify
```

To test against a custom Codex state directory:

```bash
CODEX_HOME=/path/to/custom/codex ./script/build_and_run.sh
```

Generated build artifacts should stay untracked:

- `.build/`
- `build/`
- `dist/`
- `.codex/`
- `.swiftpm/`
- `DerivedData/`

## Build

```bash
swift test
./build.sh --release
```

The release app bundle is written to:

```text
build/CodexStatusBar.app
```

The build script assembles and signs the app in a temporary staging directory, then copies final outputs into `build/`. This keeps Finder/File Provider metadata away from the app bundle used for packaging.

## Packaging

Create a local DMG:

```bash
./build.sh --dmg
hdiutil verify build/CodexStatusBar.dmg
```

The DMG is written to:

```text
build/CodexStatusBar.dmg
```

## Homebrew

The formula lives in:

```text
Formula/codex-status-bar.rb
```

Check Ruby syntax locally:

```bash
ruby -c Formula/codex-status-bar.rb
```

After the formula is pushed to the tap, validate the published install path:

```bash
brew tap yuriipalam/codex-status-bar https://github.com/yuriipalam/codex-status-bar
brew trust --formula yuriipalam/codex-status-bar/codex-status-bar
brew audit --formula yuriipalam/codex-status-bar/codex-status-bar
brew install codex-status-bar
codex-status-bar
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

```text
type: summary
```

Examples:

- `feat: show unread Codex sessions`
- `fix: ignore malformed JSONL lines`
- `docs: simplify product copy`
