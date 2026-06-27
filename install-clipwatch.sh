#!/bin/zsh
# install-clipwatch.sh — load the clipboard history + freshness/security watcher
# as a per-user LaunchAgent (starts now + at login). Generates the plist from the
# CURRENT location, so it's safe to re-run after moving this folder.
emulate -L zsh
set -uo pipefail

SCRIPT_DIR="${0:A:h}"
LABEL="com.claudecommand.clipwatch"
PY="${SCRIPT_DIR}/clipwatch.py"
DEST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/.claude/logs" "${HOME}/.claude/state"

if ! /usr/bin/python3 -c "from AppKit import NSPasteboard" 2>/dev/null; then
  print -- "[clipwatch] ERROR /usr/bin/python3 lacks PyObjC/AppKit. Install Command Line Tools."; exit 1
fi

# Generate plist pointing at the current path (relocation-safe).
cat > "$DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>${LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/python3</string>
		<string>${PY}</string>
	</array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
	<key>ProcessType</key><string>Background</string>
	<key>StandardErrorPath</key><string>${HOME}/.claude/logs/clipwatch.err</string>
	<key>StandardOutPath</key><string>${HOME}/.claude/logs/clipwatch.out</string>
</dict>
</plist>
PLIST
print -- "[clipwatch] wrote plist -> $DEST (points at $PY)"

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null
launchctl bootstrap "gui/${UID_NUM}" "$DEST" 2>/dev/null || launchctl load -w "$DEST" 2>/dev/null
launchctl kickstart -k "gui/${UID_NUM}/${LABEL}" 2>/dev/null

sleep 1
if [ -f "${HOME}/.claude/state/clipboard.json" ]; then
  print -- "[clipwatch] ✓ running — $(cat "${HOME}/.claude/state/clipboard.json")"
else
  print -- "[clipwatch] ⚠ no state yet — check ~/.claude/logs/clipwatch.err"
fi
print -- "Uninstall: launchctl bootout gui/${UID_NUM}/${LABEL}; rm '$DEST'"
