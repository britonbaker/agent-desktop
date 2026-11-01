#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build -c release
APP="$PWD/build/Rove.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Rove "$APP/Contents/MacOS/Rove"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/. "$APP/Contents/Resources/"
ENGINE_SOURCE="${ROVE_AGENT_DESKTOP_BIN:-$HOME/.nvm/versions/node/v24.12.0/lib/node_modules/agent-desktop/bin}"
cp "$ENGINE_SOURCE/agent-desktop-darwin-arm64" "$APP/Contents/Resources/agent-desktop"
cp "$ENGINE_SOURCE/agent-desktop-macos-helper-darwin-arm64" "$APP/Contents/Resources/agent-desktop-macos-helper"
SOURCE_MODELS="${ROVE_MODELS_SOURCE:-$HOME/Code/personal/aural-assistant/native/vendor/models/phonon-31m-en-coreml}"
if [[ ! -f "$APP/Contents/Resources/Models/bundle.json" ]]; then
  cp -cR "$SOURCE_MODELS" "$APP/Contents/Resources/Models"
fi
SIGNING_IDENTITY="${ROVE_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" && -f .signing-identity ]]; then
  SIGNING_IDENTITY="$(cat .signing-identity)"
fi
codesign --force --deep --sign "${SIGNING_IDENTITY:--}" "$APP"
