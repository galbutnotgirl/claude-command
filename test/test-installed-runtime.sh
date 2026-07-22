#!/bin/zsh
emulate -L zsh
set -euo pipefail

SECONDS_TO_RUN="${COMMAND_SOAK_SECONDS:-15}"
FD_GROWTH_LIMIT="${COMMAND_SOAK_FD_GROWTH_MAX:-8}"
LABEL="com.claudecommand"
SOCKET="${HOME}/.claude/state/command-agent.sock"
ERR_LOG="${HOME}/.claude/logs/command-agent.err"
DOMAIN="gui/$(id -u)/${LABEL}"

if [[ ! "$SECONDS_TO_RUN" == <-> ]] || (( SECONDS_TO_RUN < 1 )); then
  print -u2 -- "COMMAND_SOAK_SECONDS must be a positive integer"
  exit 2
fi
if [[ ! "$FD_GROWTH_LIMIT" == <-> ]]; then
  print -u2 -- "COMMAND_SOAK_FD_GROWTH_MAX must be a nonnegative integer"
  exit 2
fi

job_snapshot() {
  launchctl print "$DOMAIN" 2>/dev/null
}

job_pid() {
  job_snapshot | awk '/^[[:space:]]*pid = / { print $3; exit }'
}

file_size() {
  local target="$1"
  if [[ -f "$target" ]]; then
    stat -f %z "$target"
  else
    print -- 0
  fi
}

fd_count() {
  lsof -p "$1" 2>/dev/null | awk 'END { print NR + 0 }'
}

rss_kb() {
  ps -o rss= -p "$1" 2>/dev/null | tr -d ' ' || true
}

ping_socket() {
  local reply
  reply="$(printf 'ping\n' | nc -U -w 2 "$SOCKET" 2>/dev/null || true)"
  [[ "$reply" == "pong" ]]
}

marker="$(mktemp "${TMPDIR:-/tmp}/command-runtime-soak.XXXXXX")"
trap 'rm -f "$marker"' EXIT

initial_pid="$(job_pid)"
if [[ -z "$initial_pid" ]] || ! kill -0 "$initial_pid" 2>/dev/null; then
  print -u2 -- "FAIL: Command launchd job is not running"
  exit 1
fi
if [[ ! -S "$SOCKET" ]]; then
  print -u2 -- "FAIL: Command dispatch socket is missing"
  exit 1
fi
if ! ping_socket; then
  print -u2 -- "FAIL: Command dispatch socket did not answer pong"
  exit 1
fi

initial_err_size="$(file_size "$ERR_LOG")"
initial_fds="$(fd_count "$initial_pid")"
initial_rss="$(rss_kb "$initial_pid")"
max_fds="$initial_fds"
pings=1

for (( second = 1; second <= SECONDS_TO_RUN; second++ )); do
  sleep 1
  current_pid="$(job_pid)"
  if [[ "$current_pid" != "$initial_pid" ]] || ! kill -0 "$initial_pid" 2>/dev/null; then
    print -u2 -- "FAIL: Command restarted during soak (initial ${initial_pid}, current ${current_pid:-missing})"
    exit 1
  fi
  if ! ping_socket; then
    print -u2 -- "FAIL: dispatch socket stopped responding after ${second}s"
    exit 1
  fi
  (( pings++ ))
  current_fds="$(fd_count "$initial_pid")"
  (( current_fds > max_fds )) && max_fds="$current_fds"
done

final_rss="$(rss_kb "$initial_pid")"
if (( max_fds > initial_fds + FD_GROWTH_LIMIT )); then
  print -u2 -- "FAIL: open descriptors grew from ${initial_fds} to ${max_fds} (limit +${FD_GROWTH_LIMIT})"
  exit 1
fi

new_crashes="$(find "${HOME}/Library/Logs/DiagnosticReports" -maxdepth 1 -type f \
  \( -name 'Command*.ips' -o -name 'Command*.crash' \) -newer "$marker" -print 2>/dev/null || true)"
if [[ -n "$new_crashes" ]]; then
  print -u2 -- "FAIL: Command produced crash report during soak"
  print -u2 -- "$new_crashes"
  exit 1
fi

final_err_size="$(file_size "$ERR_LOG")"
if (( final_err_size > initial_err_size )); then
  new_err="$(tail -c +$((initial_err_size + 1)) "$ERR_LOG")"
  if print -r -- "$new_err" | grep -Eiq \
    'AttributeGraph: cycle detected|fatal error|segmentation fault|abort trap|uncaught exception|AddressSanitizer|ThreadSanitizer'; then
    print -u2 -- "FAIL: Command emitted critical diagnostics during soak"
    print -u2 -- "$new_err"
    exit 1
  fi
fi

print -- "installed runtime soak passed"
print -- "  pid: ${initial_pid} (stable)"
print -- "  socket pings: ${pings}/${pings}"
print -- "  open descriptors: ${initial_fds} initial, ${max_fds} peak"
if [[ -n "$initial_rss" && -n "$final_rss" ]]; then
  print -- "  resident memory: ${initial_rss} KB initial, ${final_rss} KB final"
fi
print -- "  new crashes: 0"
print -- "  critical diagnostics: 0"
