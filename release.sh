#!/bin/zsh
# release.sh — build ClaudeCommand.app, package it as a GitHub Release asset,
# and (with --publish) tag + upload it. Guards against the mistakes that are
# easy to make doing this by hand: releasing a dirty tree, re-releasing a
# version that's already tagged, or shipping a zip whose embedded version
# doesn't match what you think you built.
#
# The in-app updater (agent/Updater.swift) looks for the latest release on
# GH_OWNER/GH_REPO, reads its tag as the version, and downloads the first .zip
# asset. This script produces exactly that asset.
#
# Usage:
#   ./release.sh                      # build + package only, to dist/
#   ./release.sh --publish            # also tag, push the tag, and gh release create
#   ./release.sh --publish --notes "custom notes"   # skip --generate-notes
#   ./release.sh --skip-checks        # bypass the clean-tree/branch/tag guards (CI, one-offs)
#
# Bump VERSION first so the tag is newer than what users are running.
emulate -L zsh
set -uo pipefail

DIR="${0:A:h}"
VERSION="$( [ -f "${DIR}/VERSION" ] && tr -d ' \t\n' < "${DIR}/VERSION" || echo "1.0.0" )"
APP="${DIR}/ClaudeCommand.app"
DIST="${DIR}/dist"
ZIP="${DIST}/ClaudeCommand-${VERSION}.zip"
TAG="v${VERSION}"

PUBLISH=0
SKIP_CHECKS=0
NOTES=""
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-checks) SKIP_CHECKS=1 ;;
    --notes=*) NOTES="${arg#--notes=}" ;;
  esac
done

fail() { print -- "[release] $1"; exit 1; }

# ---- pre-flight guards (skippable with --skip-checks) -----------------------
if [ "$SKIP_CHECKS" = "0" ]; then
  BRANCH="$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  [ "$BRANCH" = "main" ] || fail "on branch '${BRANCH:-unknown}', not main — releases should come from main (--skip-checks to override)."

  if [ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ]; then
    fail "working tree isn't clean — commit or stash first (--skip-checks to override)."
  fi

  if git -C "$DIR" rev-parse "$TAG" >/dev/null 2>&1; then
    fail "tag ${TAG} already exists — bump VERSION first (--skip-checks to override)."
  fi

  if [ "$PUBLISH" = "1" ] && command -v gh >/dev/null 2>&1 && gh release view "$TAG" >/dev/null 2>&1; then
    fail "GitHub release ${TAG} already exists — bump VERSION first (--skip-checks to override)."
  fi
fi

print -- "[release] building ${TAG}…"
"${DIR}/build-agent.sh" || fail "build failed"
[ -d "$APP" ] || fail "missing $APP"

# The version baked into Info.plist by build-agent.sh should match VERSION
# exactly — if it doesn't, something read a stale build or a stale file.
BUILT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP}/Contents/Info.plist" 2>/dev/null)"
[ "$BUILT_VERSION" = "$VERSION" ] || fail "built Info.plist says v${BUILT_VERSION}, expected v${VERSION} — stale build?"

mkdir -p "$DIST"
rm -f "$ZIP"
# ditto -ck --keepParent → zip contains ClaudeCommand.app at top level, which is
# what Updater.install expects to find after 'ditto -xk'.
ditto -ck --keepParent "$APP" "$ZIP" || fail "zip failed"

# Sanity-check the zip actually has the app at top level, not nested or empty —
# this is exactly the shape Updater.install's unzip step assumes.
ZIP_TOP="$(unzip -Z1 "$ZIP" 2>/dev/null | head -1)"
case "$ZIP_TOP" in
  ClaudeCommand.app/*) ;;
  *) fail "packaged zip doesn't have ClaudeCommand.app at top level (saw: ${ZIP_TOP:-empty}) — Updater.install would fail to unpack this." ;;
esac

print -- "[release] packaged: ${ZIP} ($(du -h "$ZIP" | cut -f1))"

if [ "$PUBLISH" = "0" ]; then
  print -- ""
  print -- "Next (or re-run with --publish to do this automatically):"
  print -- "  git tag ${TAG} && git push origin ${TAG}"
  print -- "  gh release create ${TAG} \"${ZIP}\" --generate-notes"
  exit 0
fi

command -v gh >/dev/null 2>&1 || fail "--publish needs the gh CLI on PATH."

# Only alpha/beta tags are marked pre-release — a plain "vX.Y.Z" is a real
# stable release (see PROD_AVAILABLE in Updater.swift, which gates this).
PRERELEASE_FLAG=()
case "$TAG" in
  *alpha*|*beta*) PRERELEASE_FLAG=(--prerelease) ;;
esac

print -- "[release] tagging ${TAG}…"
git -C "$DIR" tag "$TAG" || fail "git tag failed"
git -C "$DIR" push origin "$TAG" || fail "git push (tag) failed"

print -- "[release] creating GitHub release ${TAG}…"
if [ -n "$NOTES" ]; then
  gh release create "$TAG" "$ZIP" --title "$TAG" "${PRERELEASE_FLAG[@]}" --notes "$NOTES" || fail "gh release create failed"
else
  gh release create "$TAG" "$ZIP" --title "$TAG" "${PRERELEASE_FLAG[@]}" --generate-notes || fail "gh release create failed"
fi

print -- "[release] published: https://github.com/$(git -C "$DIR" remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)\.git#\1#')/releases/tag/${TAG}"
print -- "Any installed copy will see ${TAG} via Settings → About → Check for Updates."
