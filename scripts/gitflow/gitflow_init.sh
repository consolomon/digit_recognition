#!/usr/bin/env bash
# Join the team repository and set up your own dev/<devname> branch.
#
#   scripts/gitflow/gitflow_init.sh --devname NAME
#   scripts/gitflow/gitflow_init.sh --help
#
#   --devname NAME   your developer nickname (lowercase letters, digits, - or _);
#                    your branches become dev/NAME and stage-<N>/NAME/<stage-name>
#   --help           show this help
#
# Self-contained: the tutor hands this one file out before you have a clone.
# Run it in the directory where the project folder should be created — or
# inside an existing clone of the team repository to set that clone up.
# Interactive dialog:
#   1. tools: git, gh, curl (required); docker (warning only)
#   2. GitHub login (gh auth login if needed) and protocol: https or ssh
#   3. repository owner/name; checks you can push (accepts a pending
#      invitation, or tells you to ask the tutor)
#   4. target directory (new or empty); git identity for this clone
# Then:
#   5. clone (master), store the nickname: git config gitflow.devname NAME
#   6. warn about missing REQUIRED_TOOLS (scripts/gitflow/gitflow.conf)
#   7. dev/NAME: resumes origin/dev/NAME if it exists (e.g. on a new machine),
#      otherwise creates it from master and pushes it (asks first)
# Never creates master or deploy and never changes your --global git config.
set -euo pipefail

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
confirm() { local a=""; read -r -p "$1 [y/N] " a || true; [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]; }
ask() { local a=""; read -r -p "$1${2:+ [$2]}: " a || true; printf '%s\n' "${a:-${2:-}}"; }
gf_help() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; }

DEVNAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --devname) DEVNAME="${2:-}"; shift 2 || die "--devname needs a value" ;;
    --help|-h) gf_help; exit 0 ;;
    *) gf_help >&2; exit 2 ;;
  esac
done
[ -n "$DEVNAME" ] || { gf_help >&2; die "--devname is required"; }
[[ "$DEVNAME" =~ ^[a-z0-9]+([-_][a-z0-9]+)*$ ]] || die "--devname must be lowercase letters, digits, - or _ (got '$DEVNAME')"
DEVB="dev/$DEVNAME"

info "1. tools"
for t in git gh curl; do command -v "$t" >/dev/null 2>&1 || die "'$t' is not installed"; done
command -v docker >/dev/null 2>&1 || warn "docker is not installed — needed for the local stack (scripts/gitflow/dr_rebuild.sh)"
git --version

info "2. GitHub"
if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not logged in — starting gh auth login"
  gh auth login
fi
gh auth status 2>&1 | sed -n '1,3p'
PROTO="$(ask "Protocol for git: https or ssh" https)"
case "$PROTO" in
  https) gh auth setup-git ;;
  ssh) ssh -T -o BatchMode=yes git@github.com 2>&1 | grep -q 'successfully authenticated' \
         || die "ssh to github.com failed — add your SSH key to GitHub (Settings -> SSH and GPG keys) first" ;;
  *) die "protocol must be https or ssh" ;;
esac

# Inside an existing clone? Then set that one up instead of cloning again.
IN_PLACE=""
if TOP="$(git rev-parse --show-toplevel 2>/dev/null)" && git -C "$TOP" remote get-url origin >/dev/null 2>&1; then
  if confirm "You are inside a clone ($TOP, origin $(git -C "$TOP" remote get-url origin)). Set up this clone?"; then
    IN_PLACE=1
  fi
fi

if [ -n "$IN_PLACE" ]; then
  DIR="$TOP"
  REPO="$(git -C "$DIR" remote get-url origin | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
else
  info "3. repository"
  REPO="$(ask "Team repository (owner/name, from your tutor)")"
  [[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "expected owner/name, got '$REPO'"
fi
gh repo view "$REPO" >/dev/null 2>&1 || {
  INV="$(gh api user/repository_invitations --jq ".[] | select(.repository.full_name == \"$REPO\") | .id" 2>/dev/null | head -n 1 || true)"
  [ -n "$INV" ] || die "cannot see $REPO — ask your tutor to invite you as a collaborator"
  confirm "You have a pending invitation to $REPO. Accept it?" || die "accept the invitation first"
  gh api -X PATCH "user/repository_invitations/$INV" >/dev/null
}
if [ "$(gh api "repos/$REPO" --jq .permissions.push 2>/dev/null || echo false)" != true ]; then
  INV="$(gh api user/repository_invitations --jq ".[] | select(.repository.full_name == \"$REPO\") | .id" 2>/dev/null | head -n 1 || true)"
  if [ -n "$INV" ] && confirm "You have a pending invitation to $REPO. Accept it?"; then
    gh api -X PATCH "user/repository_invitations/$INV" >/dev/null
  else
    die "you cannot push to $REPO — ask your tutor to invite you as a collaborator"
  fi
fi
echo "push access to $REPO: ok"

if [ -z "$IN_PLACE" ]; then
  info "4. local clone"
  DIR="$(ask "Directory for the project" "$(pwd)/${REPO#*/}")"
  if [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then die "$DIR exists and is not empty"; fi
  if [ "$PROTO" = ssh ]; then URL="git@github.com:$REPO.git"; else URL="https://github.com/$REPO.git"; fi
  NAME_DEF="$(git config --global user.name || true)"; MAIL_DEF="$(git config --global user.email || true)"
  GNAME="$(ask "Your name for commits" "$NAME_DEF")"; GMAIL="$(ask "Your email for commits" "$MAIL_DEF")"
  [ -n "$GNAME" ] && [ -n "$GMAIL" ] || die "name and email are required for commits"

  info "5. clone $URL"
  git clone -q --branch master "$URL" "$DIR"
  git -C "$DIR" config user.name "$GNAME"
  git -C "$DIR" config user.email "$GMAIL"
fi
cd "$DIR"
git config gitflow.devname "$DEVNAME"
git config gitflow.repo "$REPO"
git fetch -q origin

info "6. toolchain"
REQUIRED_TOOLS=""
# shellcheck disable=SC1091
[ -f scripts/gitflow/gitflow.conf ] && source scripts/gitflow/gitflow.conf
for t in $REQUIRED_TOOLS; do command -v "$t" >/dev/null 2>&1 && echo "  $t: ok" || warn "$t is not installed (REQUIRED_TOOLS)"; done
[ -n "$REQUIRED_TOOLS" ] || echo "  no REQUIRED_TOOLS configured"

info "7. $DEVB"
if git rev-parse -q --verify "refs/remotes/origin/$DEVB" >/dev/null; then
  confirm "origin already has $DEVB. Resume it here?" || die "pick another --devname"
  if git rev-parse -q --verify "refs/heads/$DEVB" >/dev/null; then git checkout -q "$DEVB"; git pull -q --ff-only origin "$DEVB"
  else git checkout -q -b "$DEVB" --track "origin/$DEVB"; fi
else
  git checkout -q -b "$DEVB" origin/master
  if confirm "Push $DEVB to origin?"; then git push -u origin "$DEVB"; else echo "not pushed — later: git push -u origin $DEVB"; fi
fi
info "ready: $DIR on $DEVB"
cat <<EOF
Next:
  cd "$DIR"
  scripts/gitflow/new_stage.sh --number 1 --name <stage-name>
EOF
