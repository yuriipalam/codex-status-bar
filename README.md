# Codex Status Bar

A compact native macOS menu bar app that shows what Codex is doing locally.

<p>
  <a href="https://github.com/yuriipalam/codex-status-bar/releases/latest/download/CodexStatusBar.dmg">
    <img alt="Download for Mac OS" src="https://img.shields.io/static/v1?label=&message=Download%20for%20Mac%20OS&color=000000&style=for-the-badge&logo=apple&logoColor=white">
  </a>
</p>

No window or dock icon. No network calls.

<img width="1280" height="720" alt="Codex Status Bar Demo" src="https://github.com/user-attachments/assets/d764f418-376d-4906-a3e8-1e26965f0de5" />

## What It Shows

- **Thinking / working** - an animated status icon with an optional live timer.
- **Running a tool** - compact labels such as `Editing`, `Reading`, `Running command`, or `Web search`.
- **Waiting for input or approval** - paused status when Codex needs a reply or permission.
- **Multiple agents** - compact counts such as `2 agents running 4m 12s` or `2 waiting 1m 0s`, timed from the newest active agent.
- **Unread sessions** - a blue-dot status for unread finished Codex sessions, and local usage indicators.
- **Idle / done** - local usage indicators.

The menu includes active and unread sessions, `APP` / `CLI` / `IDE` badges, timer and usage toggles, icon color and animation options, usage reset details, and the app version.

## Requirements

- macOS 13+
- Codex Desktop, the Codex CLI, or a Codex IDE extension.

## Install

Download the latest DMG, open it, then drag Codex Status Bar into `Applications`.

Open Codex Status Bar from `Applications`. If macOS blocks the first launch because the app is not notarized, right-click the app and choose `Open`, then confirm.

## How It Works

Codex Status Bar resolves `CODEX_HOME`, falls back to `~/.codex`, and polls local Codex session JSONL plus Codex's unread-thread state every 0.2 seconds. It derives status, elapsed time, tool labels, unread sessions, and usage snapshots from local files only.

Those Codex files are implementation details, not a stable public API. If Codex changes its local file format, Codex Status Bar may need an update.

## Privacy

Codex Status Bar reads local Codex activity files and processes them on your Mac. It does not display prompts, responses, command output, or generated thread summaries, and it does not upload telemetry, call OpenAI APIs, install hooks, or modify session logs.

The only optional write is user-approved: on first launch, Codex Status Bar can disable Codex Desktop's own duplicate menu bar icon by writing `[desktop] mac-menu-bar-enabled = false` to `$CODEX_HOME/config.toml`.

Development, source builds, packaging, and release notes live in [CONTRIBUTING.MD](CONTRIBUTING.MD).

## Acknowledgements

Thanks to [m1ckc3s](https://github.com/m1ckc3s) and his [Claude Status Bar](https://github.com/m1ckc3s/claude-status-bar) project. The original idea started there for Claude, this app is a Codex-focused take inspired by that work.

## Trademark / Not Affiliated

This is an unofficial open-source side project. It is not affiliated with, endorsed by, or sponsored by OpenAI.

Codex and OpenAI are trademarks of OpenAI. The app includes Codex icon assets for local menu-bar display. The MIT license covers this project's source code only and does not grant rights to OpenAI names, trademarks, or brand assets.

## License

MIT
