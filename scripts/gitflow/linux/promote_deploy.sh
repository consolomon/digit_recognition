#!/usr/bin/env bash
# Put your dev/<dev> on the deploy branch (incoming dev wins).
#
#   linux/promote_deploy.sh
#   linux/promote_deploy.sh --help
#
#   --help   show this help
#
# Anyone may promote; deploy then shows the promoting developer's version.
# Works in a temporary git worktree — your checkout never changes branch. Steps:
#   1. checks: dev/<dev> pushed (offers the push when it is ahead of origin)
#   2. worktree at origin/deploy; git merge -s ours dev/<dev> records the history,
#      then the files are replaced by dev/<dev>'s tree, except
#      - DEPLOY_OWNED paths (gitflow.conf; prod docker-compose.yaml,
#        .gitignore): deploy keeps its own version
#      - DEV_ONLY paths: removed (minus DEPLOY_KEEP)
#      - DEPLOY_KEEP paths: 3-way merged (a conflict stops the script)
#      VERSION is dev/<dev>'s value (carried forward).
#   3. shows what production will receive, commits
#      "<VERSION> merge: dev/<dev> → deploy" with a "Promoted-From: dev/<dev>" trailer
#   4. pushes deploy (asks first)
# This is NOT a release: the VPS pulls deploy and rebuilds by hand (printed at the end).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
  "") ;;
  --help|-h) gf_help; exit 0 ;;
  *) gf_help >&2; exit 2 ;;
esac

gf_root
gf_load_conf
DEVB="$(dev_branch)"

info "checks"
ensure_pushed "$DEVB"
git rev-parse -q --verify refs/remotes/origin/deploy >/dev/null || die "origin has no deploy branch"
SRC="$(git rev-parse "origin/$DEVB")"
DEP="$(git rev-parse origin/deploy)"
MB="$(git merge-base "$DEP" "$SRC" || true)"

WT="$(mktemp -d "${TMPDIR:-/tmp}/gf-deploy.XXXXXX")"
cleanup() { git worktree remove --force "$WT" >/dev/null 2>&1 || true; rm -rf "$WT"; git worktree prune; }
trap cleanup EXIT
git worktree add -q --detach "$WT" "$DEP"
w() { git -C "$WT" "$@"; }

info "$DEVB -> deploy (incoming dev wins)"
# History only: deploy's tree stays as it is, dev/<dev> becomes a parent.
# "Already up to date" (dev/<dev> was promoted before) leaves no MERGE_HEAD — fine.
w merge --no-ff --no-commit -s ours "$SRC" >/dev/null 2>&1 || true
# Files: dev/<dev>'s whole tree (removes what dev does not have)
w read-tree -u --reset "$SRC"

# Deploy-owned paths: deploy's own version, unconditionally
for p in ${DEPLOY_OWNED[@]+"${DEPLOY_OWNED[@]}"}; do
  w rm -r -q -f --ignore-unmatch -- "$p"
  if [ -n "$(git ls-tree -r --name-only "$DEP" -- "$p")" ]; then w checkout "$DEP" -- "$p"; fi
done
if printf '%s\n' ${DEPLOY_OWNED[@]+"${DEPLOY_OWNED[@]}"} | grep -qxF .gitignore; then
  NEW_IGN="$(comm -13 <(git show "$DEP:.gitignore" 2>/dev/null | sort -u) <(git show "$SRC:.gitignore" 2>/dev/null | sort -u) | sed '/^[[:space:]]*$/d')"
  [ -z "$NEW_IGN" ] || { warn "$DEVB's .gitignore has lines deploy does not (deploy keeps its own):"; echo "$NEW_IGN" | sed 's/^/  /' >&2; }
fi

# Dev-only paths: out of deploy (DEPLOY_KEEP excluded)
DEVONLY=(); while IFS= read -r l; do DEVONLY+=("$l"); done < <(devonly_pathspec)
[ "${#DEVONLY[@]}" -eq 0 ] || w rm -r -q -f --ignore-unmatch -- "${DEVONLY[@]}"

# DEPLOY_KEEP: 3-way merge per file, so edits made on deploy survive
KEEP_CONFLICTS=""
if [ "${#DEPLOY_KEEP[@]}" -gt 0 ]; then
  T="$(mktemp -d)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    in_src="$(git ls-tree --name-only "$SRC" -- "$f")"; in_dep="$(git ls-tree --name-only "$DEP" -- "$f")"
    if [ -z "$in_src" ]; then w checkout "$DEP" -- "$f"; w add -f -- "$f"; continue; fi
    [ -n "$in_dep" ] || continue                       # only on dev: already in place
    git show "$DEP:$f" > "$T/ours"; git show "$SRC:$f" > "$T/theirs"
    if [ -n "$MB" ] && git cat-file -e "$MB:$f" 2>/dev/null; then git show "$MB:$f" > "$T/base"; else : > "$T/base"; fi
    if git merge-file -L deploy -L base -L "$DEVB" "$T/ours" "$T/base" "$T/theirs"; then
      cp "$T/ours" "$WT/$f"; w add -f -- "$f"
    else
      KEEP_CONFLICTS+="$f"$'\n'
    fi
  done < <( { git ls-tree -r --name-only "$SRC" -- "${DEPLOY_KEEP[@]}"; git ls-tree -r --name-only "$DEP" -- "${DEPLOY_KEEP[@]}"; } | sort -u)
  rm -rf "$T"
fi
[ -z "$KEEP_CONFLICTS" ] || { printf '  %s\n' $KEEP_CONFLICTS >&2; die "DEPLOY_KEEP files edited on both deploy and $DEVB conflict — merge origin/deploy into $DEVB, resolve them, push, re-run"; }

if w diff --cached --quiet "$DEP"; then
  echo "deploy already matches $DEVB — nothing to promote"; exit 0
fi

info "production will receive (vs current deploy)"
w diff --cached --stat "$DEP" | tail -n 25
V="$(w show :VERSION | tr -d '[:space:]')"
w commit -q -m "$V merge: $DEVB → deploy" -m "Promoted-From: $DEVB"
w log -1 --format='promote: %h %s'

confirm "Push deploy to origin?" || die "not pushed — nothing changed on origin"
w push origin HEAD:refs/heads/deploy || die "push rejected (someone pushed deploy meanwhile) — re-run the script"
git fetch -q origin deploy
info "deploy is now $DEVB at $V — not released yet"
echo "Release on the VPS, in its deploy checkout: git pull --ff-only origin deploy && linux/dr_rebuild.sh"
