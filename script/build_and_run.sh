#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexStatusBar"
BUNDLE_ID="${BUNDLE_ID:-io.github.yuriipalam.codexstatusbar}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILT_APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
RUN_ROOT="${CODEX_STATUS_BAR_RUN_ROOT:-${TMPDIR:-/tmp}/codex-status-bar-run}"
RUN_APP_BUNDLE="$RUN_ROOT/$APP_NAME.app"
APP_BUNDLE="$BUILT_APP_BUNDLE"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

"$ROOT_DIR/build.sh" --debug

prepare_run_bundle() {
  rm -rf "$RUN_APP_BUNDLE"
  mkdir -p "$RUN_ROOT"
  ditto --noextattr --noacl --noqtn "$BUILT_APP_BUNDLE" "$RUN_APP_BUNDLE"
  APP_BUNDLE="$RUN_APP_BUNDLE"
  APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  strip_app_root_xattrs
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
}

strip_app_root_xattrs() {
  for _ in 1 2 3 4 5; do
    xattr -c "$APP_BUNDLE" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
    xattr -d "com.apple.fileprovider.fpfs#P" "$APP_BUNDLE" 2>/dev/null || true
    xattr -d com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
    xattr -d com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true
    xattr -d com.apple.provenance "$APP_BUNDLE" 2>/dev/null || true
    sleep 0.05

    if ! xattr -p com.apple.FinderInfo "$APP_BUNDLE" >/dev/null 2>&1 \
      && ! xattr -p "com.apple.fileprovider.fpfs#P" "$APP_BUNDLE" >/dev/null 2>&1; then
      return
    fi
  done
}

open_app() {
  prepare_run_bundle

  local open_args=(-n)
  if [[ -n "${CODEX_HOME:-}" ]]; then
    open_args+=(--env "CODEX_HOME=$CODEX_HOME")
  fi

  /usr/bin/open "${open_args[@]}" "$APP_BUNDLE"
  strip_app_root_xattrs
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    strip_app_root_xattrs
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running"
    ;;
  *)
    usage
    exit 2
    ;;
esac
