#!/bin/bash
# Merge dev into deploy: strips dev-only tooling and resources/ (except the
# DEPLOY_KEEP allowlist), then commits and pushes. See
# resources/documentation/GITFLOW.md for the rules around this script,
# especially the DEPLOY_KEEP overwrite hazard. Adapted from TechProSvet's
# script (2026-10-17) — the hard-won fixes in the comments below come from
# that project's incidents.
set -e

echo "--- Merging dev into deploy ---"

# Paths under resources/ that deploy needs on disk (operational docs someone
# running the VPS needs in hand). Written on dev, only read on deploy — add
# entries here, not by hand-editing the deploy branch. See
# resources/documentation/GITFLOW.md §DEPLOY_KEEP.
DEPLOY_KEEP=(
  "resources/documentation/GITFLOW.md"
  "resources/documentation/GITFLOW_INIT.md"
  "resources/documentation/DEPLOY_INIT.md"
)

git checkout deploy
git pull origin deploy
# || true: a conflict here is expected and normal — it's how git reports
# "deploy deleted this path (by design: .claude/, scripts/, resources/) but
# dev modified it since," which happens every time dev touches one of those
# paths after the last promotion. set -e would otherwise abort right here,
# before any of this script's own conflict-resolution logic below ever
# runs. A merge failure for any OTHER reason is caught by the fresh
# conflict check at the end instead.
git merge --no-ff --no-commit dev || true

# Nothing to merge ("Already up to date") leaves no MERGE_HEAD. Stop here:
# everything below restores from MERGE_HEAD, and without it the strip steps
# would commit the removal of every DEPLOY_KEEP path from deploy.
if ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  echo "deploy already contains dev — nothing to promote."
  exit 0
fi

# Capture the conflict set BEFORE any index rewrite below, since git rm/add
# clear the unmerged flag on the paths they touch — checking after would
# silently miss conflicts on those paths. Used only for the DEPLOY_KEEP
# hazard check right below; the final "did we resolve everything" check
# further down re-reads live state instead, since resolving .claude/scripts
# conflicts (right after this) legitimately clears entries from this list.
CONFLICTED="$(git diff --name-only --diff-filter=U || true)"

# .gitignore exists on both sides by design (deploy adds its own lines, e.g.
# resources/), so any dev edit to it conflicts. Resolve by UNION of lines —
# safe for an ignore file (it can only ignore more) — and say so loudly.
# Stages: :1 base, :2 ours (deploy), :3 theirs (dev).
if echo "$CONFLICTED" | grep -qxF ".gitignore"; then
  GI_TMP="$(mktemp -d)"
  git show :1:.gitignore > "$GI_TMP/base" 2>/dev/null || : > "$GI_TMP/base"
  git show :2:.gitignore > "$GI_TMP/ours"
  git show :3:.gitignore > "$GI_TMP/theirs"
  git merge-file --union "$GI_TMP/ours" "$GI_TMP/base" "$GI_TMP/theirs"
  cp "$GI_TMP/ours" .gitignore
  git add .gitignore
  rm -rf "$GI_TMP"
  echo "WARNING: .gitignore conflict auto-resolved as the UNION of deploy's and dev's lines — review deploy's .gitignore after this promotion."
fi

# Remove dev-only tooling brought in by the merge. -f: these are expected
# modify/delete conflicts (deploy deleted, dev modified) whenever dev has
# touched .claude/ or scripts/ since the last promotion — force-remove
# resolves them correctly, since these paths must never exist on deploy
# regardless of what dev did to them.
git rm --cached -rf .claude 2>/dev/null || true
git rm --cached -rf scripts 2>/dev/null || true

# Strip resources/ wholesale, then restore only the DEPLOY_KEEP allowlist.
git rm --cached -rf resources 2>/dev/null || true

for path in "${DEPLOY_KEEP[@]}"; do
  # A path that doesn't exist on dev yet is skipped, not an error.
  if ! git cat-file -e "MERGE_HEAD:$path" 2>/dev/null; then
    echo "skipped $path (not on dev)"
    continue
  fi
  # Exact file match, or any conflicted file under a directory entry.
  if echo "$CONFLICTED" | grep -qxF "$path" || echo "$CONFLICTED" | grep -qF "$path/"; then
    echo "ERROR: DEPLOY_KEEP path '$path' has an unresolved conflict — merge it by hand, then re-run." >&2
    exit 1
  fi
  # MERGE_HEAD (dev's incoming version), NOT HEAD (deploy's stale copy from
  # whenever this path was last restored). These paths are documented as
  # "written on dev, only read on deploy" — dev's version is supposed to
  # always win. Restoring from HEAD instead silently reverts every
  # DEPLOY_KEEP doc to however old it was at the LAST promotion, discarding
  # everything written on dev since (TechProSvet, 2026-09-14).
  git checkout MERGE_HEAD -- "$path"
  # -f: resources/ is .gitignore'd on deploy (see
  # resources/documentation/GITFLOW_INIT.md's branch inventory), so a plain
  # `git add` here is refused as an ignored path.
  git add -f "$path"
  echo "updated to dev's $path"
done

# VERSION isn't under resources/ so the strip/restore above doesn't touch
# it, but it hits the same class of problem: deploy gets direct commits
# (its own docker-compose.yaml, the init commit), which bump VERSION
# independently of dev, so a plain merge can conflict on it. Same fix, same
# reasoning — dev's value wins; a promotion is a carry-forward, not a new
# value.
if echo "$CONFLICTED" | grep -qxF "VERSION"; then
  git checkout MERGE_HEAD -- VERSION
  git add VERSION
  echo "resolved VERSION conflict: took dev's value"
fi

# Fresh check, not $CONFLICTED — .claude/scripts conflicts were just
# resolved above on purpose, and would otherwise still show up in the
# stale snapshot and wrongly abort a promotion that actually succeeded.
STILL_CONFLICTED="$(git diff --name-only --diff-filter=U || true)"
if [ -n "$STILL_CONFLICTED" ]; then
  echo "ERROR: unresolved conflicts remain:" >&2
  echo "$STILL_CONFLICTED" >&2
  exit 1
fi

# Merge commits carry the version forward unchanged (CLAUDE.md §"Commit
# message versioning") — VERSION already holds dev's value post-merge, no
# bump needed.
git commit -m "$(cat VERSION) merge: sync dev → deploy ($(date +%Y-%m-%d))"
git push origin deploy

echo "--- Done ---"
