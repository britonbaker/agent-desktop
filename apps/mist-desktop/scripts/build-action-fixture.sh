#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
fixture="/tmp/RoveActionFixture.app"
mkdir -p "$fixture/Contents/MacOS"
xcrun swiftc Tests/ActionFixture.swift -o "$fixture/Contents/MacOS/RoveActionFixture.next"
mv -f "$fixture/Contents/MacOS/RoveActionFixture.next" "$fixture/Contents/MacOS/RoveActionFixture"
cat > "$fixture/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.briton.rove.actionfixture</string><key>CFBundleExecutable</key><string>RoveActionFixture</string><key>CFBundleName</key><string>Rove Action Fixture</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
codesign --force --sign - "$fixture"
print "$fixture"
