#!/bin/zsh
# uninstall-quick-action.sh — remove all "Send to Claude" Quick Actions.
emulate -L zsh
set -uo pipefail
NAMES=(
  "Claude - New"
  "Claude - Go"
  "Claude - Add"
  "Claude - Reformat"
  "Claude - To-Do"
  "Claude - Screenshot New"
  "Claude - Screenshot Go"
  "Claude - Screenshot Full"
  "Claude - Clipboard History"
  "Claude - Comment"           # legacy names
  "Claude - Screenshot Comment"
  "Send to Claude — Comment"   # legacy names
  "Send to Claude — Go"
  "Fix Format (Claude)"
  "Send to Claude Code"
)
removed=0
for n in "${NAMES[@]}"; do
  b="${HOME}/Library/Services/${n}.workflow"
  if [ -d "$b" ]; then rm -rf "$b"; print -- "[uninstall] removed ${n}.workflow"; removed=1; fi
done
if [ "$removed" = "1" ]; then
  /System/Library/CoreServices/pbs -flush 2>/dev/null
  /System/Library/CoreServices/pbs -update 2>/dev/null
  print -- "[uninstall] flushed Services cache"
else
  print -- "[uninstall] nothing to remove"
fi
