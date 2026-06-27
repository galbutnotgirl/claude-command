#!/bin/zsh
# install-agent.sh — load CommandAgent as a per-user LaunchAgent (starts now +
# at login, kept alive). Generates the plist from the CURRENT path, so it's safe
# to re-run after moving this folder. Re-run also picks up a rebuilt binary.
emulate -L zsh
set -uo pipefail

DIR="${0:A:h}"
LABEL="com.claudecommand"
# Install app to ~/Applications so macOS shows its icon in Background Activity.
INSTALL_APP="${HOME}/Applications/ClaudeCommand.app"
BIN="${INSTALL_APP}/Contents/MacOS/ClaudeCommand"
DEST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

SRC_APP="${DIR}/ClaudeCommand.app"
[ -x "${SRC_APP}/Contents/MacOS/ClaudeCommand" ] || { print -- "[agent] missing ClaudeCommand.app — run ./build-agent.sh first"; exit 1; }

# Copy app to ~/Applications so macOS can show its icon in Background Activity.
mkdir -p "${HOME}/Applications"
rm -rf "$INSTALL_APP"
cp -aR "$SRC_APP" "$INSTALL_APP"
print -- "[agent] installed -> ${INSTALL_APP}"

mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/.claude/logs" "${HOME}/.claude/state"

cat > "$DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>${LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>${BIN}</string>
	</array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
	<key>ProcessType</key><string>Interactive</string>
	<key>StandardErrorPath</key><string>${HOME}/.claude/logs/claude-command.err</string>
	<key>StandardOutPath</key><string>${HOME}/.claude/logs/claude-command.out</string>
</dict>
</plist>
PLIST
print -- "[agent] wrote plist -> $DEST (points at $BIN)"

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null
launchctl bootstrap "gui/${UID_NUM}" "$DEST" 2>/dev/null || launchctl load -w "$DEST" 2>/dev/null
launchctl kickstart -k "gui/${UID_NUM}/${LABEL}" 2>/dev/null

sleep 1
if [ -S "${HOME}/.claude/state/command-agent.sock" ]; then
  print -- "[agent] ✓ running — socket up at ~/.claude/state/command-agent.sock"
else
  print -- "[agent] ⚠ socket not up yet — check ~/.claude/logs/command-agent.err (likely needs Accessibility grant)"
fi
print -- "Uninstall: launchctl bootout gui/${UID_NUM}/${LABEL}; rm '$DEST'"
