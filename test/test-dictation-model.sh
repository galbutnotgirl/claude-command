#!/bin/zsh
# Local release-machine integration test. Uses cached Parakeet models and system TTS;
# CI does not download the ~650 MB model bundle.
emulate -L zsh
set -euo pipefail

DIR="${0:A:h:h}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

AUDIO="$TMP_DIR/final-words.aiff"
EXPECTED="bright yellow lantern"
/usr/bin/say -v Samantha -r 185 -o "$AUDIO" \
  "Command dictation must keep every phrase, including the final words bright yellow lantern."

AUDIO_BYTES="$(/usr/bin/afinfo "$AUDIO" | awk '/audio bytes:/ { print $3; exit }')"
if [[ -z "$AUDIO_BYTES" || "$AUDIO_BYTES" -le 0 ]]; then
  print -u2 "dictation fixture generation failed: macOS say produced no audio"
  exit 2
fi

cd "$DIR/agent"
swift run -c release DictationModelProbe "$AUDIO" "$EXPECTED"
