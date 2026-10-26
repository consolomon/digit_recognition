#!/usr/bin/env bash
# Finish the current stage: merge stage-<N>/<dev>/<name> into your dev/<dev>.
#
#   linux/finish_stage.sh
#   linux/finish_stage.sh --help
#
#   --help   show this help
#
# Run it on the stage branch, with everything committed. Steps:
#   1. checks: you are on one of YOUR stage-*/<dev>/* branches, the tree is clean
#   2. test gate: TEST_CMD from gitflow.conf (if set), then the
#      question "manual test in local Docker passed?" (linux/dr_rebuild.sh)
#   3. git checkout dev/<dev>, git pull --ff-only,
#      git merge --no-ff --no-commit stage-<N>/<dev>/<name>
#      - a VERSION conflict takes the higher value
#      - any other conflict: the merge is aborted, you are back on the stage
#        branch with instructions
#   4. commit "<VERSION> merge: finish stage-<N>/<dev>/<name>" (version carried forward)
#   5. push dev/<dev>, delete the stage branch locally and on origin (asks first)
# You end on dev/<dev>.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
  "") ;;
  --help|-h) gf_help; exit 0 ;;
  *) gf_help >&2; exit 2 ;;
esac

gf_root
gf_load_conf
DEV="$(devname)"
DEVB="dev/$DEV"
STAGE="$(current_branch)"

info "checks"
RE_STAGE="^stage-[0-9]+/$DEV/[a-z0-9-]+\$"
[[ "$STAGE" =~ $RE_STAGE ]] \
  || die "current branch '$STAGE' is not one of your stage branches (stage-<N>/$DEV/<name>)"
require_clean_tree

info "test gate"
if [ -n "$TEST_CMD" ]; then
  echo "\$ $TEST_CMD"
  bash -c "$TEST_CMD" || die "automated tests failed — fix them on $STAGE"
else
  echo "no automated tests configured (TEST_CMD in $GF_CONF)"
fi
confirm "Manual test of $STAGE in local Docker (linux/dr_rebuild.sh) passed?" \
  || die "finish the manual test first"

info "merge $STAGE -> $DEVB"
git fetch -q origin
git checkout -q "$DEVB"
if git rev-parse -q --verify "refs/remotes/origin/$DEVB" >/dev/null; then
  git pull -q --ff-only origin "$DEVB" || { git checkout -q "$STAGE"; die "$DEVB has diverged from origin/$DEVB — reconcile it by hand"; }
fi
git merge --no-ff --no-commit "$STAGE" >/dev/null 2>&1 || true
resolve_version_conflict
LEFT="$(git diff --name-only --diff-filter=U)"
if [ -n "$LEFT" ]; then
  git merge --abort
  git checkout -q "$STAGE"
  echo "$LEFT" | sed 's/^/  conflict: /' >&2
  die "the merge conflicts — on $STAGE run: git merge $DEVB, resolve the files above, commit, then re-run this script"
fi
if ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  echo "$DEVB already contains $STAGE — nothing to merge"
else
  git commit -q -m "$(read_version) merge: finish $STAGE"
  git log -1 --format='merged: %h %s'
fi

if confirm "Push $DEVB to origin?"; then
  git push origin "$DEVB"
else
  echo "not pushed — later: git push origin $DEVB"
fi
if confirm "Delete $STAGE locally and on origin?"; then
  # -D after an explicit check: -d also compares with origin/<stage>, which may lack the last commits
  git merge-base --is-ancestor "$STAGE" "$DEVB" || die "$STAGE is not fully merged into $DEVB — not deleted"
  git branch -D "$STAGE"
  if git rev-parse -q --verify "refs/remotes/origin/$STAGE" >/dev/null; then git push origin --delete "$STAGE"; fi
fi
info "on $DEVB — share it with linux/promote_master.sh, deploy it with linux/promote_deploy.sh"
