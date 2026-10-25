#!/usr/bin/env bash
# Start a new project stage: branch stage-<N>/<dev>/<name> from your own dev/<dev>.
#
#   scripts/gitflow/new_stage.sh --number N --name NAME
#   scripts/gitflow/new_stage.sh --help
#
#   --number N    stage number (whole number >= 1); becomes F in the G.F.P version
#   --name NAME   short stage name, lowercase letters, digits and dashes
#                 (e.g. digit-recognition) -> branch stage-N/<dev>/NAME
#   --help        show this help
#
# Steps:
#   1. checks: developer name set (gitflow_init.sh), arguments valid, the stage
#      branch does not exist yet locally or on origin
#   2. uncommitted work: offers to stash it as "wip <branch>", or stops
#   3. git checkout dev/<dev>, git pull --ff-only, git checkout -b stage-N/<dev>/NAME
#   4. first commit: VERSION = G.N.0, message "G.N.0 start stage N: NAME"
#   5. push the new branch to origin (asks first)
# You stay on the stage branch. Every later commit there bumps P by hand:
#   G.N.P -> G.N.(P+1) in VERSION, commit message "G.N.(P+1) <subject>".
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NUMBER=""; NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --number) NUMBER="${2:-}"; shift 2 || die "--number needs a value" ;;
    --name)   NAME="${2:-}"; shift 2 || die "--name needs a value" ;;
    --help|-h) gf_help; exit 0 ;;
    *) gf_help >&2; exit 2 ;;
  esac
done

[ -n "$NUMBER" ] && [ -n "$NAME" ] || { gf_help >&2; die "--number and --name are both required"; }
[[ "$NUMBER" =~ ^[1-9][0-9]*$ ]] || die "--number must be a whole number >= 1 (got '$NUMBER')"
[[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "--name must be lowercase letters, digits and single dashes (got '$NAME')"

gf_root
DEV="$(devname)"
DEVB="dev/$DEV"
STAGE="stage-$NUMBER/$DEV/$NAME"

info "checks"
git fetch -q origin
git rev-parse -q --verify "refs/heads/$DEVB" >/dev/null \
  || git rev-parse -q --verify "refs/remotes/origin/$DEVB" >/dev/null \
  || die "$DEVB does not exist — run scripts/gitflow/gitflow_init.sh first"
EXISTING="$( { git branch --list "stage-$NUMBER/$DEV/*" --format='%(refname:short)'
               git branch -r --list "origin/stage-$NUMBER/$DEV/*" --format='%(refname:short)'; } | sort -u)"
[ -z "$EXISTING" ] || die "you already have a stage-$NUMBER branch: $(echo "$EXISTING" | tr '\n' ' ')— finish it first (scripts/gitflow/finish_stage.sh)"

if ! tree_is_clean; then
  git status --short
  confirm "Uncommitted changes on $(current_branch). Stash them as \"wip $(current_branch)\"?" \
    || die "commit or stash your changes first"
  git stash push -u -m "wip $(current_branch)"
fi

info "$DEVB -> $STAGE"
git checkout -q "$DEVB" 2>/dev/null || git checkout -q -b "$DEVB" --track "origin/$DEVB"
if git rev-parse -q --verify "refs/remotes/origin/$DEVB" >/dev/null; then
  git pull -q --ff-only origin "$DEVB" || die "$DEVB has diverged from origin/$DEVB — reconcile it by hand"
fi
CUR="$(read_version)"
F_NOW="$(echo "$CUR" | cut -d. -f2)"
[ "$NUMBER" -ge "$F_NOW" ] || warn "stage $NUMBER is lower than the current stage number in VERSION ($CUR)"
git checkout -q -b "$STAGE"

NEW="$(stage_version "$CUR" "$NUMBER")"
echo "$NEW" > VERSION
git add VERSION
git commit -q -m "$NEW start stage $NUMBER: $NAME"
git log -1 --format='first commit: %h %s'

if confirm "Push $STAGE to origin (visible to the team, backed up)?"; then
  git push -u origin "$STAGE"
else
  echo "not pushed — later: git push -u origin $STAGE"
fi
info "on $STAGE — build the stage, then scripts/gitflow/finish_stage.sh"
