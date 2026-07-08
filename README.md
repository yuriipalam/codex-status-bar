# Codex Status Bar

A compact native macOS menu bar app that shows what Codex is doing locally.

No window or dock icon. No network calls.

<img width="720" height="720" alt="CodexStatusBarDemo" src="https://github.com/user-attachments/assets/1aa7932c-e4a5-4a78-9947-16268728cc87" />

## What It Shows

- **Thinking / working** - an animated status icon with an optional live timer.
- **Running a tool** - compact labels such as `Editing`, `Reading`, `Running command`, or `Web search`.
- **Waiting for input or approval** - paused status when Codex needs a reply or permission.
- **Multiple agents** - compact counts such as `2 agents running 4m 12s` or `2 waiting 1m 0s`, timed from the newest active agent.
- **Unread sessions** - a blue-dot status for unread finished Codex sessions, and local usage indicators.
- **Idle / done** - local usage indicators.

The menu includes active and unread sessions, `APP` / `CLI` / `IDE` badges, usage reset details, an Options submenu for toggles, color and animation controls, and the app version.

## Requirements

- macOS 13+
- Codex Desktop, the Codex CLI, or a Codex IDE extension.

## Install

### Homebrew

Recommended for developers. Homebrew builds Codex Status Bar from source and launches the app from Homebrew's install location.

```bash
brew tap yuriipalam/codex-status-bar https://github.com/yuriipalam/codex-status-bar
brew install codex-status-bar
codex-status-bar
```

### DMG

<p>
  <a href="https://github.com/yuriipalam/codex-status-bar/releases/latest/download/CodexStatusBar.dmg">
    <img alt="Download for Mac OS" src="https://img.shields.io/static/v1?label=&message=Download%20for%20Mac%20OS&color=000000&style=for-the-badge&logo=apple&logoColor=white">
  </a>
</p>

Download the latest DMG, open it, then drag `CodexStatusBar.app` into `Applications`.

The DMG is not Developer ID signed or notarized yet. If macOS blocks the first launch, keep the app and remove the downloaded-app quarantine:

```bash
xattr -dr com.apple.quarantine /Applications/CodexStatusBar.app
open /Applications/CodexStatusBar.app
```

You can also use Apple's UI override: try opening the app once, then open System Settings > Privacy & Security and click `Open Anyway`. Apple documents that flow in [Safely open apps on your Mac](https://support.apple.com/en-us/102445).

## How It Works

Codex Status Bar resolves `CODEX_HOME`, falls back to `~/.codex`, and polls local Codex session JSONL plus Codex's unread-thread state every 0.2 seconds. It derives status, elapsed time, tool labels, unread sessions, and usage snapshots from local files only.

Those Codex files are implementation details, not a stable public API. If Codex changes its local file format, Codex Status Bar may need an update.

## Privacy

Codex Status Bar reads local Codex activity files and processes them on your Mac. It does not display prompts, responses, command output, or generated thread summaries, and it does not upload telemetry, call OpenAI APIs, install hooks, or modify session logs.

The only optional write is user-approved: on first launch, Codex Status Bar can disable Codex Desktop's own duplicate menu bar icon by writing `[desktop] mac-menu-bar-enabled = false` to `$CODEX_HOME/config.toml`.

Development, source builds, and packaging live in [CONTRIBUTING.MD](CONTRIBUTING.MD). Release notes live in [CHANGELOG.md](CHANGELOG.md).

## Acknowledgements

Thanks to [m1ckc3s](https://github.com/m1ckc3s) and his [Claude Status Bar](https://github.com/m1ckc3s/claude-status-bar) project. The original idea started there for Claude, this app is a Codex-focused take inspired by that work.

## Trademark / Not Affiliated

This is an unofficial open-source side project. It is not affiliated with, endorsed by, or sponsored by OpenAI.

Codex and OpenAI are trademarks of OpenAI. The app includes Codex icon assets for local menu-bar display. The MIT license covers this project's source code only and does not grant rights to OpenAI names, trademarks, or brand assets.

## License

MIT
