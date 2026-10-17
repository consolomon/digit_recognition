#!/bin/bash
# Compute the next G.F.P project version per CLAUDE.md
# §"Commit message versioning". Prints the new version to stdout — does
# NOT write VERSION or commit anything, so it composes safely:
#
#   NEW=$(scripts/next_version.sh patch)
#   echo "$NEW" > VERSION
#   git add VERSION ...
#   git commit -m "$NEW <subject>"
#
# Modes:
#   patch       (default) — P += 1. Every commit that is neither a
#               generation bump nor the first commit on a new feature
#               branch, including commits made directly on dev/master/deploy.
#   feature     — F += 1, P = 0. Use ONLY for the first commit on a
#               newly created feature/* branch.
#   generation  — G += 1, F = 0, P = 0. Use ONLY when the project owner has
#               explicitly instructed a generation bump for this commit.
#
# Merge commits (feature->dev, dev->master, dev->deploy) are NOT a mode
# here — they carry the version of the commit being merged unchanged. Just
# read VERSION directly for those; do not call this script.
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
VERSION_FILE="$REPO_ROOT/VERSION"
MODE="${1:-patch}"

if [ ! -f "$VERSION_FILE" ]; then
    echo "ERROR: $VERSION_FILE not found." >&2
    exit 1
fi

CURRENT="$(cat "$VERSION_FILE")"
G="$(echo "$CURRENT" | cut -d. -f1)"
F="$(echo "$CURRENT" | cut -d. -f2)"
P="$(echo "$CURRENT" | cut -d. -f3)"

case "$MODE" in
    generation)
        G=$((G + 1)); F=0; P=0
        ;;
    feature)
        F=$((F + 1)); P=0
        ;;
    patch)
        P=$((P + 1))
        ;;
    *)
        echo "ERROR: unknown mode '$MODE' — use generation, feature, or patch." >&2
        exit 1
        ;;
esac

echo "${G}.${F}.${P}"
