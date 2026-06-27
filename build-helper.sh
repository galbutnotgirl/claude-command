#!/bin/zsh
# build-helper.sh — compile SendHelper.swift into a codesigned .app with a stable
# bundle id, so its Accessibility grant sticks. Output: SendHelper.app next to this.
emulate -L zsh
set -uo pipefail

DIR="${0:A:h}"
SRC="${DIR}/helper/SendHelper.swift"
APP="${DIR}/SendHelper.app"
BIN_DIR="${APP}/Contents/MacOS"
BUNDLE_ID="com.claudecommand.helper"

[ -f "$SRC" ] || { print -- "[helper] missing $SRC"; exit 1; }
rm -rf "$APP"
mkdir -p "$BIN_DIR"

print -- "[helper] compiling…"
if ! swiftc -O "$SRC" -o "${BIN_DIR}/sendhelper" 2>&1; then
  print -- "[helper] ERROR swiftc failed"; exit 1
fi

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>sendhelper</string>
	<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
	<key>CFBundleName</key><string>SendHelper</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>LSUIElement</key><true/>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

# Code signing identity — ad-hoc by default; set SIGN_ID to a Keychain cert name
# (or Developer ID) so TCC grants survive rebuilds. Mirrors build-agent.sh.
SIGN_ID="${SIGN_ID:--}"
codesign --force --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP" \
  && print -- "[helper] codesigned ($SIGN_ID)" \
  || { print -- "[helper] ERROR codesign failed (SIGN_ID=$SIGN_ID)"; exit 1; }

print -- "[helper] built: $APP"
print -- "[helper] smoke test (frontapp): $("${BIN_DIR}/sendhelper" frontapp 2>/dev/null || echo '?')"
print -- ""
print -- "First ⌘C/⌘V use prompts for Accessibility for 'SendHelper' — allow once, done forever."
