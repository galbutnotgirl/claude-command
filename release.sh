#!/bin/zsh
# release.sh — build ClaudeCommand.app and package it as a GitHub Release asset.
#
# The in-app updater (agent/Updater.swift) looks for the latest release on
# GH_OWNER/GH_REPO, reads its tag as the version, and downloads the first .zip
# asset. This script produces exactly that asset.
#
# Usage:
#   ./release.sh                 # build + zip to dist/ClaudeCommand-<version>.zip
#   gh release create "v$(cat VERSION)" dist/ClaudeCommand-*.zip --generate-notes
#
# Bump VERSION first so the tag is newer than what users are running.
emulate -L zsh
set -uo pipefail

DIR="${0:A:h}"
VERSION="$( [ -f "${DIR}/VERSION" ] && tr -d ' \t\n' < "${DIR}/VERSION" || echo "1.0.0" )"
APP="${DIR}/ClaudeCommand.app"
DIST="${DIR}/dist"
ZIP="${DIST}/ClaudeCommand-${VERSION}.zip"

print -- "[release] building v${VERSION}…"
"${DIR}/build-agent.sh" || { print -- "[release] build failed"; exit 1; }
[ -d "$APP" ] || { print -- "[release] missing $APP"; exit 1; }

mkdir -p "$DIST"
rm -f "$ZIP"
# ditto -ck --keepParent → zip contains ClaudeCommand.app at top level, which is
# what Updater.install expects to find after 'ditto -xk'.
ditto -ck --keepParent "$APP" "$ZIP" || { print -- "[release] zip failed"; exit 1; }

print -- "[release] packaged: ${ZIP} ($(du -h "$ZIP" | cut -f1))"
print -- ""
print -- "Next:"
print -- "  git tag v${VERSION} && git push origin v${VERSION}   # or let gh create the tag"
print -- "  gh release create v${VERSION} \"${ZIP}\" --generate-notes"
print -- ""
print -- "Then any installed copy will see v${VERSION} via Settings → About → Check for Updates."
