# Codex Bar

A tiny native macOS menu bar app for local Codex activity.

Codex Bar shows whether Codex is thinking, working, running a tool, waiting for input or permission, or idle. It can also show local 5-hour and weekly usage snapshots when Codex writes rate-limit data into its local session logs.

No window. No Dock icon. No hooks. No network calls.

> [!IMPORTANT]
> Codex Bar is source-first. You can build a local app or DMG without an Apple Developer account. Without Developer ID signing and notarization, downloaded builds will show the normal macOS Gatekeeper warning.

## What It Shows

- **Thinking / working**: animated icon with a live timer, for example `Thinking 1m 0s`.
- **Running a tool**: short labels such as `Editing`, `Reading`, `Running command`, or `Web search`.
- **Waiting for input**: paused status with `Waiting for input` when Codex needs a reply.
- **Awaiting permission**: paused status with `Awaiting approval` and a green dot when Codex needs approval.
- **Multiple agents**: compact count such as `2 agents running 4m 12s` or `2 waiting 1m 0s`, timed from the newest active session.
- **Unread sessions**: blue-dot status such as `1 unread 5h88% w54%` when Codex has unread inactive sessions.
- **Idle / done**: usage summary, when available.

The menu includes:

- `Open Codex`
- active local Codex sessions, plus sessions Codex marks unread, labeled by working-folder name with `APP`/`CLI`/`IDE` badges when Codex records a recognized app, CLI, or IDE source
- `Show timer`
- `Show 5-hour usage`
- `Show weekly usage`
- `Color` icon style, with `System` and `Colorful` variants
- `Animation` icon style, with `Orbit`, `Pulse`, and `Pulsing Orbit` variants
- 5-hour and weekly usage/reset details
- app version
- `Quit Codex Bar`

## Privacy

Codex Bar reads local Codex activity state in read-only mode:

```text
$CODEX_HOME/sessions/**/*.jsonl
$CODEX_HOME/.codex-global-state.json
```

If `CODEX_HOME` is not set in Codex Bar's environment, it defaults to `~/.codex`.
It polls session files by modification time and parses only enough local JSONL data to derive active status, elapsed time, and the latest usage snapshot. It reads Codex's own `unread-thread-ids-by-host-v1` state to decide whether inactive sessions belong in the dropdown.
The dropdown session list uses the local working-folder name plus Codex `originator` metadata; it does not display prompts, responses, command output, or generated thread summaries. Desktop session rows can open their Codex thread directly; CLI and IDE rows are shown for context. Codex itself remains the read/unread source of truth.
The only Codex config write is optional: on first launch, if you accept the duplicate-icon prompt, Codex Bar writes only `[desktop] mac-menu-bar-enabled = false` to `$CODEX_HOME/config.toml`, then asks whether to relaunch Codex Desktop now. If you choose to relaunch now, Codex Bar sends Codex Desktop a normal quit request and opens it again; it does not force quit Codex.

Codex Bar does **not**:

- read `~/.codex/state_5.sqlite`;
- install Codex hooks;
- modify Codex session data;
- read icon files from the app bundle at runtime;
- call OpenAI account APIs;
- make network requests;
- upload telemetry.

Session JSONL files can contain sensitive local prompts, paths, tool calls, and command output. Codex Bar processes them locally and does not display conversation content in the dropdown.

## Requirements

- macOS 13+
- Codex Desktop, the Codex CLI, or a Codex IDE extension installed and writing local session files under `$CODEX_HOME/sessions` (default: `~/.codex/sessions`)
- Swift 5.9+ to build from source

## Build

```bash
swift test
./build.sh --release
```

By default, the local app bundle is written to:

```text
build/CodexBar.app
```

The build script signs and packages from a temporary staging directory, then copies final outputs into `build/`. This keeps the signed app used for the DMG away from Finder/File Provider metadata that synced folders can attach to `.app` bundles.

The build script follows the normal macOS distribution shape:

- If a `Developer ID Application` certificate is present, it signs with hardened runtime and timestamp.
- If no certificate is present, it falls back to ad-hoc signing for local/open-source builds.

To create a local DMG:

```bash
./build.sh --dmg
```

The DMG is written to:

```text
build/CodexBar.dmg
```

For distribution, use the DMG. `build/CodexBar.app` is a local convenience copy.

Without Developer ID credentials, the DMG is not notarized. That is expected for this open-source setup.

## Run Locally

```bash
./script/build_and_run.sh
```

To test a custom Codex state directory:

```bash
CODEX_HOME=/path/to/custom/codex ./script/build_and_run.sh
```

For a launch check:

```bash
./script/build_and_run.sh --verify
```

## Distribution Status

The current repo supports source builds and local DMG packaging. It does not require paying Apple to build or run locally.

For a clean public download with no Gatekeeper warning, a maintainer would still need:

1. A final bundle identifier.
2. Developer ID Application signing.
3. Hardened runtime.
4. Notarization with Apple.
5. Stapling.

`build.sh --dmg` already has the optional path for this. Set the relevant environment variables before building:

```bash
BUNDLE_ID=io.github.yuriipalam.codexbar \
CODEX_BAR_TEAM_ID=ABCDE12345 \
NOTARY_PROFILE=codexbar \
./build.sh --dmg
```

The default bundle identifier is `io.github.yuriipalam.codexbar`. Override `BUNDLE_ID` only if you are publishing your own fork under a different namespace.

Until those credentials exist, expect downloaded builds to require the user to explicitly approve opening the app in macOS.

Apple references:

- [Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [Distribute outside the Mac App Store](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html)

## How It Works

Codex Bar resolves the Codex state root from `CODEX_HOME`, falling back to `~/.codex`, then polls local Codex session JSONL files and Codex's persisted unread-thread state every 0.2 seconds. It derives:

- active state from open `task_started` events without later completion;
- status labels from recent response/tool events;
- elapsed time from the active turn start;
- unread state from Codex's `unread-thread-ids-by-host-v1` state;
- usage from the latest `token_count` rate-limit snapshot.

This uses local Codex implementation details, not a stable public API. If Codex changes its session file format, Codex Bar may need an update.

## Development

```bash
swift test
./script/build_and_run.sh --verify
```

Generated build artifacts are ignored:

- `.build/`
- `build/`
- `dist/`
- `.codex/`

## Contributing

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

```text
type(scope): summary
```

Examples:

- `feat(menu): show unread Codex sessions`
- `fix(parser): ignore malformed JSONL lines`
- `docs(readme): clarify unsigned DMG behavior`

## Trademark / Not Affiliated

This is an unofficial open-source side project. It is not affiliated with, endorsed by, or sponsored by OpenAI.

Codex and OpenAI are trademarks of OpenAI. The app includes Codex SVG icon assets for local menu-bar display. The MIT license covers this project's source code only and does not grant rights to OpenAI names, trademarks, or brand assets.

## License

MIT
