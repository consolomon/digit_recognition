#!/bin/bash
# Merge dev into deploy: keeps deploy's own production files (DEPLOY_OWNED),
# strips dev-only paths (DEV_ONLY, except the DEPLOY_KEEP allowlist), then
# commits and pushes. See resources/documentation/GITFLOW.md for the rules
# around this script. Adapted from TechProSvet's script (2026-10-17) — the
# hard-won fixes in the comments below come from that project's and
# Sreda-obitaniya's incidents.
#
# The three arrays below are also read at run time by
# .claude/commands/sync-deploy-vps.md (the VPS-side sync) — keep them as
# plain `NAME=(` … `)` blocks, one path per line.
set -e

echo "--- Merging dev into deploy ---"

# Paths deploy owns: always deploy's own version, whatever dev did to them.
DEPLOY_OWNED=(
  "docker-compose.yaml"
)

# Paths that never reach deploy (minus the DEPLOY_KEEP entries under them).
DEV_ONLY=(
  "resources"
)

# Paths under DEV_ONLY that deploy needs on disk (operational docs someone
# running the VPS needs in hand). They take git's ordinary 3-way merge, so
# an edit made on deploy (e.g. by /sync-deploy-vps) survives a promotion.
# See resources/documentation/GITFLOW.md §DEPLOY_KEEP.
DEPLOY_KEEP=(
  "resources/documentation/GITFLOW.md"
  "resources/documentation/GITFLOW_INIT.md"
  "resources/documentation/DEPLOY_INIT.md"
)

git checkout deploy
git pull origin deploy
# || true: a conflict here is expected and normal — e.g. dev edited
# docker-compose.yaml, which deploy owns (resolved below). set -e would
# otherwise abort right here, before any of this script's own
# conflict-resolution logic below ever runs. A merge failure for any OTHER
# reason is caught by the fresh conflict check at the end instead.
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
# further down re-reads live state instead, since resolving the
# DEPLOY_OWNED / DEV_ONLY paths legitimately clears entries from this list.
CONFLICTED="$(git diff --name-only --diff-filter=U || true)"

# Deploy-owned paths: put deploy's own version back unconditionally — not
# only on a conflict. After a /sync-deploy-vps back-port, git can see dev's
# side of these paths as dev's change and would otherwise merge it in
# silently (Sreda-obitaniya, "ancestry flip").
for path in "${DEPLOY_OWNED[@]}"; do
  git rm --cached -rfq --ignore-unmatch -- "$path"
  if git cat-file -e "HEAD:$path" 2>/dev/null; then
    git checkout HEAD -- "$path"
  fi
done

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

# DEPLOY_KEEP conflicts can't be auto-resolved: stop before touching them.
for path in "${DEPLOY_KEEP[@]}"; do
  # Exact file match, or any conflicted file under a directory entry.
  if echo "$CONFLICTED" | grep -qxF "$path" || echo "$CONFLICTED" | grep -qF "$path/"; then
    echo "ERROR: DEPLOY_KEEP path '$path' has an unresolved conflict — merge it by hand, then re-run." >&2
    exit 1
  fi
done

# Strip dev-only paths from the index. -f: a modify/delete conflict on them
# (deploy never had them, dev modified them) resolves correctly by removal.
# The working tree keeps git's merge result for every file, including the
# DEPLOY_KEEP ones restored next.
for path in "${DEV_ONLY[@]}"; do
  git rm --cached -rfq --ignore-unmatch -- "$path"
done

for path in "${DEPLOY_KEEP[@]}"; do
  if [ ! -e "$path" ]; then
    # Absent after the merge: not on dev yet, or deleted by the merge.
    echo "skipped $path (absent after the merge)"
    continue
  fi
  # Re-stage git's 3-way merge result from the working tree: edits made on
  # dev AND on deploy both survive. Neither "always dev's copy" (silently
  # reverts deploy-side edits — Sreda-obitaniya lost VPS execution records
  # that way) nor "always deploy's copy" (TechProSvet, 2026-09-14: silently
  # reverted every dev-side doc update) is safe. Real conflicts were
  # stopped above.
  # -f: resources/ is .gitignore'd on deploy (see
  # resources/documentation/GITFLOW_INIT.md's branch inventory), so a plain
  # `git add` here is refused as an ignored path.
  git add -f -- "$path"
  echo "kept merged $path"
done

# VERSION hits the same class of problem: deploy gets direct commits (its own
# docker-compose.yaml, VPS hotfixes via /sync-deploy-vps), which bump VERSION
# independently of dev, so a plain merge can conflict on it. Dev's value
# wins; a promotion is a carry-forward, not a new value.
if echo "$CONFLICTED" | grep -qxF "VERSION"; then
  git checkout MERGE_HEAD -- VERSION
  git add VERSION
  echo "resolved VERSION conflict: took dev's value"
fi

# Fresh check, not $CONFLICTED — the DEPLOY_OWNED / DEV_ONLY conflicts were
# just resolved above on purpose, and would otherwise still show up in the
# stale snapshot and wrongly abort a promotion that actually succeeded.
STILL_CONFLICTED="$(git diff --name-only --diff-filter=U || true)"
if [ -n "$STILL_CONFLICTED" ]; then
  echo "ERROR: unresolved conflicts remain:" >&2
  echo "$STILL_CONFLICTED" >&2
  exit 1
fi

# The strip leaves dev-only files on disk (ignored on deploy). Never delete
# them here: on the dev PC that would also hit uncommitted drafts under
# resources/. `git checkout dev` puts the tracked ones back in place.

# Merge commits carry the version forward unchanged (CLAUDE.md §"Commit
# message versioning") — VERSION already holds dev's value post-merge, no
# bump needed.
git commit -m "$(cat VERSION) merge: sync dev → deploy ($(date +%Y-%m-%d))"
git push origin deploy

echo "--- Done ---"
