#!/usr/bin/env bash
# Builds CodexBar.app, and optionally a local DMG with: ./build.sh --dmg
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="CodexBar"
DISPLAY_NAME="Codex Bar"
BUNDLE_NAME="$APP_NAME.app"
VOLUME_NAME="Codex Bar"
CONFIGURATION="${CONFIGURATION:-release}"
MAKE_DMG=0
OUTPUT_DIR="$ROOT_DIR/build"
STAGING_DIR="${CODEX_BAR_STAGING_DIR:-}"
CLEAN_STAGING_DIR=0

BUNDLE_ID="${BUNDLE_ID:-io.github.yuriipalam.codexbar}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-13.0}"
TEAM_ID="${CODEX_BAR_TEAM_ID:-${TEAM_ID:-}}"
NOTARY_PROFILE="${NOTARY_PROFILE:-codexbar}"
SKIP_NOTARIZE="${CODEX_BAR_SKIP_NOTARIZE:-${SKIP_NOTARIZE:-0}}"
APP_ICON_NAME="CodexBarAppIcon"
APP_ICON_SVG="$ROOT_DIR/Sources/CodexBar/Resources/$APP_ICON_NAME.svg"
APP_ICON_PNG="$ROOT_DIR/Sources/CodexBar/Resources/$APP_ICON_NAME.png"
APP_ICON_SOURCE="$ROOT_DIR/Sources/CodexBar/Resources/$APP_ICON_NAME.icns"
ICONSET_DIR="$ROOT_DIR/.build/$APP_ICON_NAME.iconset"

usage() {
  echo "usage: $0 [--debug|--release] [--dmg]" >&2
  echo "" >&2
  echo "Environment overrides:" >&2
  echo "  BUNDLE_ID=io.github.yuriipalam.codexbar" >&2
  echo "  APP_VERSION=0.1.0 BUILD_NUMBER=1" >&2
  echo "  CODEX_BAR_TEAM_ID=ABCDE12345 NOTARY_PROFILE=codexbar" >&2
  echo "  SKIP_NOTARIZE=1" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      CONFIGURATION="debug"
      shift
      ;;
    --release)
      CONFIGURATION="release"
      shift
      ;;
    --dmg)
      MAKE_DMG=1
      CONFIGURATION="release"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$STAGING_DIR" ]]; then
  TMP_BASE="${TMPDIR:-/tmp}"
  TMP_BASE="${TMP_BASE%/}"
  STAGING_DIR="$(mktemp -d "$TMP_BASE/codexbar-build.XXXXXX")"
  CLEAN_STAGING_DIR=1
fi

cleanup() {
  if [[ "$CLEAN_STAGING_DIR" == "1" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT
mkdir -p "$OUTPUT_DIR" "$STAGING_DIR"

render_app_icon() {
  if [[ ! -f "$APP_ICON_SVG" ]]; then
    echo "ERROR: missing app icon source: $APP_ICON_SVG" >&2
    exit 1
  fi

  if [[ -f "$APP_ICON_PNG" && -f "$APP_ICON_SOURCE" \
    && ! "$APP_ICON_SVG" -nt "$APP_ICON_PNG" \
    && ! "$APP_ICON_SVG" -nt "$APP_ICON_SOURCE" ]]; then
    return
  fi

  if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "ERROR: rsvg-convert is required to render $APP_ICON_SVG" >&2
    exit 1
  fi
  if ! command -v sips >/dev/null 2>&1; then
    echo "ERROR: sips is required to resize app icon assets." >&2
    exit 1
  fi
  if ! command -v iconutil >/dev/null 2>&1; then
    echo "ERROR: iconutil is required to create $APP_ICON_SOURCE" >&2
    exit 1
  fi

  echo "Rendering app icon from $APP_ICON_SVG"
  rsvg-convert -w 1024 -h 1024 -f png "$APP_ICON_SVG" -o "$APP_ICON_PNG"

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$APP_ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  iconutil -c icns -o "$APP_ICON_SOURCE" "$ICONSET_DIR"
}

if [[ "$CONFIGURATION" == "release" ]]; then
  swift build -c release
  BUILD_BIN_DIR="$(swift build -c release --show-bin-path)"
else
  swift build
  BUILD_BIN_DIR="$(swift build --show-bin-path)"
fi

BUILD_BINARY="$BUILD_BIN_DIR/$APP_NAME"
APP_BUNDLE="$STAGING_DIR/$BUNDLE_NAME"
PUBLIC_APP_BUNDLE="$OUTPUT_DIR/$BUNDLE_NAME"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

render_app_icon
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp -X "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp -X "$APP_ICON_SOURCE" "$APP_RESOURCES/CodexBarAppIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>CodexBarAppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

clean_signing_detritus() {
  local target="$1"
  find "$target" \( -name '._*' -o -name '.DS_Store' \) -delete 2>/dev/null || true
  dot_clean -m "$target" 2>/dev/null || true
  xattr -cr "$target" 2>/dev/null || true
  while IFS= read -r -d '' item; do
    xattr -c "$item" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
    xattr -d com.apple.ResourceFork "$item" 2>/dev/null || true
    xattr -d com.apple.quarantine "$item" 2>/dev/null || true
    xattr -d "com.apple.fileprovider.fpfs#P" "$item" 2>/dev/null || true
    xattr -d com.apple.provenance "$item" 2>/dev/null || true
  done < <(find "$target" -print0)
  xattr -c "$target" 2>/dev/null || true
  xattr -d com.apple.FinderInfo "$target" 2>/dev/null || true
  xattr -d "com.apple.fileprovider.fpfs#P" "$target" 2>/dev/null || true
  xattr -d com.apple.provenance "$target" 2>/dev/null || true
}

strip_forbidden_root_xattrs() {
  local target="$1"

  for _ in 1 2 3 4 5; do
    xattr -c "$target" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$target" 2>/dev/null || true
    xattr -d com.apple.ResourceFork "$target" 2>/dev/null || true
    xattr -d com.apple.quarantine "$target" 2>/dev/null || true
    xattr -d "com.apple.fileprovider.fpfs#P" "$target" 2>/dev/null || true
    xattr -d com.apple.provenance "$target" 2>/dev/null || true
    sleep 0.05

    if ! xattr -p com.apple.FinderInfo "$target" >/dev/null 2>&1 \
      && ! xattr -p "com.apple.fileprovider.fpfs#P" "$target" >/dev/null 2>&1; then
      return
    fi
  done
}

find_developer_id() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  if [[ -n "$TEAM_ID" ]]; then
    printf "%s\n" "$identities" \
      | grep "Developer ID Application" \
      | grep "$TEAM_ID" \
      | head -1 \
      | sed -E 's/.*"([^"]+)".*/\1/' \
      || true
  else
    printf "%s\n" "$identities" \
      | grep "Developer ID Application" \
      | head -1 \
      | sed -E 's/.*"([^"]+)".*/\1/' \
      || true
  fi
}

sign_app() {
  local sign_id="$1"

  if [[ -n "$sign_id" ]]; then
    echo "Signing app with Developer ID: $sign_id"
  else
    if [[ -n "$TEAM_ID" ]]; then
      echo "No Developer ID cert for team $TEAM_ID found; ad-hoc signing for local/open-source build."
    else
      echo "No Developer ID cert found; ad-hoc signing for local/open-source build."
    fi
  fi

  for attempt in 1 2 3 4 5; do
    clean_signing_detritus "$APP_BUNDLE"
    sleep 0.2
    clean_signing_detritus "$APP_BUNDLE"
    strip_forbidden_root_xattrs "$APP_BUNDLE"

    local sign_status=0
    if [[ -n "$sign_id" ]]; then
      codesign --force --options runtime --timestamp --sign "$sign_id" "$APP_BUNDLE" || sign_status=$?
    else
      codesign --force --sign - "$APP_BUNDLE" >/dev/null || sign_status=$?
    fi

    strip_forbidden_root_xattrs "$APP_BUNDLE"
    if [[ "$sign_status" == "0" ]] && codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"; then
      return
    fi

    if [[ "$attempt" != "5" ]]; then
      echo "Retrying app signing after clearing bundle metadata."
      sleep 0.25
    fi
  done

  echo "ERROR: app signing failed after clearing bundle metadata." >&2
  exit 1
}

detach_existing_volume() {
  hdiutil info | awk -v name="$VOLUME_NAME" '$0 ~ name {print $1}' | while IFS= read -r device; do
    hdiutil detach "$device" >/dev/null 2>&1 || true
  done
}

attach_dmg() {
  local dmg="$1"
  shift
  local output
  output="$(hdiutil attach "$@" "$dmg")"
  local device
  local mount_point
  device="$(printf "%s\n" "$output" | awk 'index($0, "/Volumes/") {print $1; exit}')"
  mount_point="$(printf "%s\n" "$output" | awk 'index($0, "/Volumes/") {sub(/^.*\/Volumes\//, "/Volumes/"); print; exit}')"
  if [[ -z "$device" || -z "$mount_point" ]]; then
    echo "ERROR: failed to attach $dmg" >&2
    printf "%s\n" "$output" >&2
    exit 1
  fi
  printf "%s\t%s\n" "$device" "$mount_point"
}

notarize_app_if_possible() {
  local sign_id="$1"

  if [[ -z "$sign_id" ]]; then
    echo "Skipping app notarization: no Developer ID cert."
    return
  fi

  if [[ "$SKIP_NOTARIZE" == "1" ]]; then
    echo "SKIP_NOTARIZE=1: app signed but not notarized."
    return
  fi

  echo "Notarizing app with notarytool profile '$NOTARY_PROFILE'."
  rm -f "$STAGING_DIR/app-notarize.zip"
  ditto -c -k --keepParent "$APP_BUNDLE" "$STAGING_DIR/app-notarize.zip"
  xcrun notarytool submit "$STAGING_DIR/app-notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$STAGING_DIR/app-notarize.zip"
}

publish_app_bundle() {
  rm -rf "$PUBLIC_APP_BUNDLE"
  ditto --noextattr --noacl --noqtn "$APP_BUNDLE" "$PUBLIC_APP_BUNDLE"
  clean_signing_detritus "$PUBLIC_APP_BUNDLE"
  strip_forbidden_root_xattrs "$PUBLIC_APP_BUNDLE"
  echo "Built $PUBLIC_APP_BUNDLE"
}

create_dmg() {
  local sign_id="$1"
  local dmg="$OUTPUT_DIR/$APP_NAME.dmg"
  local rw_dmg="$STAGING_DIR/rw.dmg"

  notarize_app_if_possible "$sign_id"

  echo "Packaging DMG."
  rm -f "$dmg" "$rw_dmg"

  detach_existing_volume

  # Build the image by copying into a writable volume. On File Provider-backed
  # folders, hdiutil -srcfolder can add FinderInfo xattrs to .app bundles and
  # make codesign --strict reject the app inside the DMG.
  hdiutil create -volname "$VOLUME_NAME" -size "${DMG_SIZE_MB:-32}m" -fs HFS+ -ov "$rw_dmg" >/dev/null

  local attach_result
  local device
  local mount_point
  attach_result="$(attach_dmg "$rw_dmg" -readwrite -noverify -noautoopen)"
  device="$(printf "%s" "$attach_result" | cut -f1)"
  mount_point="$(printf "%s" "$attach_result" | cut -f2)"

  ditto --noextattr --noacl --noqtn "$APP_BUNDLE" "$mount_point/$BUNDLE_NAME"
  ln -s /Applications "$mount_point/Applications"
  clean_signing_detritus "$mount_point/$BUNDLE_NAME"
  strip_forbidden_root_xattrs "$mount_point/$BUNDLE_NAME"
  if ! codesign --verify --deep --strict --verbose=2 "$mount_point/$BUNDLE_NAME"; then
    hdiutil detach "$device" >/dev/null 2>&1 || true
    echo "ERROR: staged app inside writable DMG failed codesign verification." >&2
    exit 1
  fi

  local mounted_volume_name
  mounted_volume_name="$(basename "$mount_point")"

  osascript <<OSA || echo "Finder layout skipped; DMG still contains the app and Applications shortcut."
tell application "Finder"
  tell disk "$mounted_volume_name"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 200, 880, 540}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 100
    set text size of viewOptions to 12
    set position of item "$BUNDLE_NAME" of container window to {130, 150}
    set position of item "Applications" of container window to {350, 150}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

  clean_signing_detritus "$mount_point/$BUNDLE_NAME"
  strip_forbidden_root_xattrs "$mount_point/$BUNDLE_NAME"
  if ! codesign --verify --deep --strict --verbose=2 "$mount_point/$BUNDLE_NAME"; then
    hdiutil detach "$device" >/dev/null 2>&1 || true
    echo "ERROR: laid-out app inside writable DMG failed codesign verification." >&2
    exit 1
  fi
  find "$mount_point" -maxdepth 1 -name ".*" ! -name ".DS_Store" -exec rm -rf {} + 2>/dev/null || true
  sync
  hdiutil detach "$device" >/dev/null || true

  hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg" >/dev/null
  rm -f "$rw_dmg"

  local verify_result
  local verify_device
  local verify_mount
  verify_result="$(attach_dmg "$dmg" -nobrowse -noautoopen -readonly)"
  verify_device="$(printf "%s" "$verify_result" | cut -f1)"
  verify_mount="$(printf "%s" "$verify_result" | cut -f2)"
  local stray
  stray="$(find "$verify_mount" -maxdepth 1 -name ".*" ! -name ".DS_Store" 2>/dev/null || true)"
  if ! codesign --verify --deep --strict --verbose=2 "$verify_mount/$BUNDLE_NAME"; then
    hdiutil detach "$verify_device" >/dev/null 2>&1 || true
    echo "ERROR: app inside DMG failed codesign verification." >&2
    exit 1
  fi
  hdiutil detach "$verify_device" >/dev/null 2>&1 || true
  if [[ -n "$stray" ]]; then
    echo "ERROR: DMG has stray hidden entries:" >&2
    echo "$stray" >&2
    exit 1
  fi
  echo "DMG verified clean."

  clean_signing_detritus "$APP_BUNDLE"
  strip_forbidden_root_xattrs "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

  if [[ -n "$sign_id" ]]; then
    echo "Signing DMG with Developer ID: $sign_id"
    codesign --force --timestamp --sign "$sign_id" "$dmg"
    if [[ "$SKIP_NOTARIZE" != "1" ]]; then
      echo "Notarizing DMG with notarytool profile '$NOTARY_PROFILE'."
      xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
      xcrun stapler staple "$dmg"
    else
      echo "SKIP_NOTARIZE=1: DMG signed but not notarized."
    fi
  else
    echo "DMG is not Developer ID signed or notarized; Gatekeeper warnings are expected on downloaded copies."
  fi

  echo "Built $dmg"
}

SIGN_ID="$(find_developer_id)"
sign_app "$SIGN_ID"
publish_app_bundle

if [[ "$MAKE_DMG" == "1" ]]; then
  create_dmg "$SIGN_ID"
fi
