#!/bin/zsh
emulate -L zsh
set -uo pipefail

DIR="${0:A:h:h}"
INSTALLER="${DIR}/install-agent.sh"
TMP_ROOT="$(mktemp -d)"
FAKE_HOME="${TMP_ROOT}/home"
FAKE_BIN="${TMP_ROOT}/bin"
SOURCE_APP="${TMP_ROOT}/source/Command.app"
DEFAULTS_LOG="${TMP_ROOT}/defaults.log"
PASS=0
FAIL=0
trap 'rm -rf "$TMP_ROOT"' EXIT

ok() { print -- "ok - $1"; PASS=$((PASS + 1)); }
not_ok() { print -- "not ok - $1: $2"; FAIL=$((FAIL + 1)); }

assert_true() {
  local name="$1"
  shift
  if "$@"; then ok "$name"; else not_ok "$name" "condition failed"; fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then ok "$name"; else not_ok "$name" "missing '$needle'"; fi
}

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then ok "$name"; else not_ok "$name" "unexpected '$needle'"; fi
}

mkdir -p "$FAKE_BIN" "$SOURCE_APP/Contents/MacOS"
cat > "$SOURCE_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Command</string>
  <key>CFBundleIdentifier</key><string>com.claudecommand</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>9.9.9-test</string>
</dict></plist>
PLIST
print '#!/bin/sh\nexit 0' > "$SOURCE_APP/Contents/MacOS/Command"
chmod +x "$SOURCE_APP/Contents/MacOS/Command"
codesign --force --sign - --identifier com.claudecommand "$SOURCE_APP" >/dev/null 2>&1

cat > "$FAKE_BIN/launchctl" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$FAKE_BIN/pkill" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$FAKE_BIN/defaults" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$COMMAND_TEST_DEFAULTS_LOG"
if [ "$1" = "read" ]; then
  [ "${COMMAND_TEST_DEFAULTS_EXIST:-0}" = "1" ] && exit 0
  exit 1
fi
exit 0
SH
chmod +x "$FAKE_BIN/launchctl" "$FAKE_BIN/pkill" "$FAKE_BIN/defaults"

run_install() {
  HOME="$FAKE_HOME" \
  PATH="$FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  COMMAND_SOURCE_APP="$SOURCE_APP" \
  COMMAND_SKIP_LSREGISTER=1 \
  COMMAND_SOCKET_WAIT_ATTEMPTS=0 \
  COMMAND_TEST_DEFAULTS_LOG="$DEFAULTS_LOG" \
  COMMAND_TEST_DEFAULTS_EXIST="${1:-0}" \
  zsh "$INSTALLER" 2>&1
}

FRESH_OUTPUT="$(run_install 0)"
FRESH_DEFAULTS="$(cat "$DEFAULTS_LOG")"
assert_true "fresh install copies app" test -x "$FAKE_HOME/Applications/Command.app/Contents/MacOS/Command"
assert_true "fresh install writes LaunchAgent" test -f "$FAKE_HOME/Library/LaunchAgents/com.claudecommand.plist"
assert_contains "fresh install defaults Clipboard History off" "write com.claudecommand cliphistoryEnabled -bool false" "$FRESH_DEFAULTS"
assert_contains "fresh install clears onboarding completion" "delete com.claudecommand onboardingCompleted" "$FRESH_DEFAULTS"
assert_contains "fresh install reports onboarding" "fresh install — onboarding will run on first launch" "$FRESH_OUTPUT"

: > "$DEFAULTS_LOG"
INCREMENTAL_OUTPUT="$(run_install 1)"
INCREMENTAL_DEFAULTS="$(cat "$DEFAULTS_LOG")"
assert_contains "incremental install updates in place" "updated in-place" "$INCREMENTAL_OUTPUT"
assert_not_contains "incremental install preserves onboarding" "delete com.claudecommand onboardingCompleted" "$INCREMENTAL_DEFAULTS"
assert_not_contains "incremental install preserves Clipboard History preference" "write com.claudecommand cliphistoryEnabled" "$INCREMENTAL_DEFAULTS"

print -- ""
print -- "install state tests: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
