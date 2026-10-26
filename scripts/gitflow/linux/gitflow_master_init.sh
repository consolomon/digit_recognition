#!/usr/bin/env bash
# Create the team's gitflow repository from the starter pack (tutor / team lead).
#
#   linux/gitflow_master_init.sh
#   linux/gitflow_master_init.sh --help
#
#   --help   show this help
#
# Run it from the kit: the folder that holds linux/, macos/ and win/ (the
# scripts for each OS, each with its README.md), README.md (the course repo's
# front page), gitflow.conf and the starter pack starter/ — a plain folder
# anywhere, or scripts/gitflow/ inside a project. Any working directory works
# (symlinks to the script too).
#
# Interactive dialog:
#   1. tools: git, gh (logged in)
#   2. GitHub owner (you or one of your organisations), repository name,
#      visibility, description, protocol (https / ssh), your git identity
#   3. local directory for the new repository (new or empty)
#   4. values baked into the starter files: domain, certbot email, web host
#      port, app port (__DOMAIN__, __CERTBOT_EMAIL__, __WEB_HOST_PORT__, __APP_PORT__)
#   5. gitflow.conf: APP_DIR, WEB_SERVICE, TEST_CMD,
#      IMAGE_TEST_CMD, REQUIRED_TOOLS
#   6. GitHub logins to invite as collaborators (optional)
#
# Then, after a summary and your confirmation:
#   - checks the kit (every script of linux/, macos/ and win/ with its
#     README.md, README.md, gitflow.conf, every file in starter/MANIFEST) and
#     that the GitHub repository does NOT exist yet
#   - master: the starter/ contents (minus _deploy/ and MANIFEST) at the root,
#     README.md, the generated gitflow.conf, a .gitattributes keeping the
#     scripts' LF line endings, and the folders linux/, macos/ and win/ (all
#     scripts but the master init) -> commit "<VERSION> init: starter pack"
#   - deploy: master + the starter/_deploy/ overlay (prod docker-compose.yaml)
#     -> commit "<VERSION+1 patch> init deploy branch: prod compose"
#   - creates the GitHub repository, pushes master and deploy, allows merge
#     commits only (PR title = merge commit title, keeps the G.F.P prefix),
#     invites the collaborators, tries "require a pull request" on master
# No dev branch is created — everyone, you included, runs gitflow_init.
#
# Your own dev branch:  cd "/home/consolomon/Documents/Code sandbox/<repo_name>" && linux/gitflow_init.sh --devname <your-nickname>
# Invite more later:    gh api -X PUT repos/consolomon/<repo_name>/collaborators/<login> -f permission=push
set -euo pipefail
# The kit is the folder above the one holding the real script file (symlinks resolved)
SRC="${BASH_SOURCE[0]}"
while [ -L "$SRC" ]; do
  D="$(cd -P "$(dirname "$SRC")" && pwd)"; SRC="$(readlink "$SRC")"; [[ "$SRC" == /* ]] || SRC="$D/$SRC"
done
SELF_DIR="$(cd -P "$(dirname "$SRC")" && pwd)"
KIT="$(dirname "$SELF_DIR")"
source "$SELF_DIR/lib.sh"
GF_CONF="$KIT/gitflow.conf"

case "${1:-}" in
  "") ;;
  --help|-h) gf_help; exit 0 ;;
  *) gf_help >&2; exit 2 ;;
esac

PACK="$KIT/starter"
# Per OS: folder and script extension; every folder gets these scripts (+ README.md)
OS_DIRS=(linux macos win); OS_EXTS=(sh tool cmd)
BASES=(lib new_stage finish_stage promote_master promote_deploy sync_deploy_vps dr_rebuild gitflow_init)
# The folder the kit belongs to: the project around scripts/gitflow/, or the kit itself
case "$KIT" in */scripts/gitflow) KIT_HOME="$(cd "$KIT/../.." && pwd)" ;; *) KIT_HOME="$KIT" ;; esac

info "1. tools"
need_cmd git; need_cmd gh "https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh is not logged in — run: gh auth login"
echo "kit: $KIT"
for f in README.md gitflow.conf; do [ -f "$KIT/$f" ] || die "$KIT/$f not found — the kit is incomplete"; done
for i in 0 1 2; do
  [ -f "$KIT/${OS_DIRS[$i]}/README.md" ] || die "$KIT/${OS_DIRS[$i]}/README.md not found — the kit is incomplete"
  for b in "${BASES[@]}"; do
    [ -f "$KIT/${OS_DIRS[$i]}/$b.${OS_EXTS[$i]}" ] || die "$KIT/${OS_DIRS[$i]}/$b.${OS_EXTS[$i]} not found — the kit is incomplete"
  done
done
[ -f "$PACK/MANIFEST" ] || die "$PACK/MANIFEST not found — the starter pack must sit in the kit"
MISSING=""
while IFS= read -r f; do
  f="${f%%#*}"; f="$(echo "$f" | xargs)"; [ -n "$f" ] || continue
  [ -f "$PACK/$f" ] || MISSING="$MISSING  $PACK/$f"$'\n'
done < "$PACK/MANIFEST"
[ -z "$MISSING" ] || { printf '%s' "$MISSING" >&2; die "the starter pack is incomplete (files listed in $PACK/MANIFEST)"; }
for f in "${OS_DIRS[@]}" README.md gitflow.conf; do
  [ ! -e "$PACK/$f" ] || die "$PACK/$f clashes with the kit's own $f at the repository root — rename or remove it"
done
PACK_V="$(tr -d '[:space:]' < "$PACK/VERSION")"
[[ "$PACK_V" =~ $VERSION_RE ]] || die "$PACK/VERSION is not G.F.P (got '$PACK_V')"

info "2. GitHub repository"
ME="$(gh api user --jq .login)"
ORGS="$(gh api user/orgs --jq '.[].login' 2>/dev/null | tr '\n' ' ' || true)"
[ -z "$ORGS" ] || echo "your organisations: $ORGS"
OWNER="$(ask "Owner (your login or an organisation)" "$ME")"
NAME="$(ask "Repository name")"
RE_NAME='^[A-Za-z0-9_.-]+$'
[[ "$NAME" =~ $RE_NAME ]] || die "invalid repository name '$NAME'"
REPO="$OWNER/$NAME"
! gh repo view "$REPO" >/dev/null 2>&1 || die "$REPO already exists — this script only creates new repositories"
VIS="$(ask "Visibility: private or public" private)"
case "$VIS" in private|public) ;; *) die "visibility must be private or public" ;; esac
DESC="$(ask "Description" "Digit recognition — gitflow learning project")"
PROTO="$(ask "Protocol for git: https or ssh" https)"
case "$PROTO" in https|ssh) ;; *) die "protocol must be https or ssh" ;; esac
GNAME="$(ask "Your name for commits" "$(git config --global user.name || true)")"
GMAIL="$(ask "Your email for commits" "$(git config --global user.email || true)")"
[ -n "$GNAME" ] && [ -n "$GMAIL" ] || die "name and email are required for commits"

info "3. local directory"
DEST="$(ask "Directory for the new repository" "$(dirname "$KIT_HOME")/$NAME")"
DEST="${DEST//\\//}"                          # Windows: C:\x -> C:/x
case "$DEST" in /*|[A-Za-z]:/*) ;; *) DEST="$(pwd)/$DEST" ;; esac
if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then die "$DEST exists and is not empty"; fi
case "$DEST/" in "$KIT/"*) die "$DEST is inside the kit — pick a folder outside $KIT" ;; esac
P_DIR="$DEST"; while [ ! -d "$P_DIR" ]; do P_DIR="$(dirname "$P_DIR")"; done
if OUTER="$(git -C "$P_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  confirm "$DEST would sit inside the git repository $OUTER. Continue anyway?" || die "stopped — pick a folder outside $OUTER"
fi

info "4. values baked into the starter files"
DOMAIN="$(ask "Production domain" "example.org")"
CERTBOT_EMAIL="$(ask "Certbot registration email" "$GMAIL")"
WEB_HOST_PORT="$(ask "Local host port of the web server" 8008)"
APP_PORT="$(ask "Port the app listens on inside its container" 8008)"
RE_PORT='^[0-9]+$'
[[ "$WEB_HOST_PORT" =~ $RE_PORT ]] && [[ "$APP_PORT" =~ $RE_PORT ]] || die "ports must be numbers"

info "5. gitflow.conf"
gf_load_conf
APP_DIR="$(ask "Docker build context of the app (APP_DIR)" "$APP_DIR")"
WEB_SERVICE="$(ask "Compose service of the app (WEB_SERVICE)" "$WEB_SERVICE")"
TEST_CMD="$(ask "Host test command for finish_stage (TEST_CMD, empty = none)" "")"
IMAGE_TEST_CMD="$(ask "Test command inside the new image for dr_rebuild (IMAGE_TEST_CMD, empty = none)" "")"
REQUIRED_TOOLS="$(ask "Language toolchain to check, space-separated (REQUIRED_TOOLS, empty = none)" "")"

info "6. collaborators"
COLLABS=()
read -r -a COLLABS <<< "$(ask "GitHub logins to invite, space-separated (empty = later)" "")" || true

info "summary"
cat <<EOF
  repository     $REPO ($VIS, $PROTO) — "$DESC"
  local          $DEST
  identity       $GNAME <$GMAIL>
  starter        $DOMAIN, $CERTBOT_EMAIL, host port $WEB_HOST_PORT, app port $APP_PORT
  gitflow.conf   APP_DIR=$APP_DIR WEB_SERVICE=$WEB_SERVICE
                 TEST_CMD=${TEST_CMD:-<none>} IMAGE_TEST_CMD=${IMAGE_TEST_CMD:-<none>} REQUIRED_TOOLS=${REQUIRED_TOOLS:-<none>}
  collaborators  ${COLLABS[*]:-<none>}
  scripts        linux/ (.sh), macos/ (.tool), win/ (.cmd)
  branches       master ($PACK_V), deploy ($(bump_patch "$PACK_V"))
EOF
confirm "Create the repository locally now? (GitHub is asked separately)" || die "stopped — nothing created"

# sed replacement text: escape \ & and the | delimiter
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
bake() {   # bake <dir>: replace the placeholders in every text file below <dir>
  local f
  grep -rlI -e __DOMAIN__ -e __CERTBOT_EMAIL__ -e __WEB_HOST_PORT__ -e __APP_PORT__ "$1" 2>/dev/null \
    | while IFS= read -r f; do
        # no sed -i (GNU and BSD spell it differently): rewrite in place, keeping the file's mode
        sed -e "s|__DOMAIN__|$(esc "$DOMAIN")|g" -e "s|__CERTBOT_EMAIL__|$(esc "$CERTBOT_EMAIL")|g" \
            -e "s|__WEB_HOST_PORT__|$(esc "$WEB_HOST_PORT")|g" -e "s|__APP_PORT__|$(esc "$APP_PORT")|g" "$f" > "$f.gf-bake"
        cat "$f.gf-bake" > "$f"; rm -f "$f.gf-bake"
      done
}
q() { printf '%q' "$1"; }    # shell-quote a value for gitflow.conf

info "master"
mkdir -p "$DEST"
cp -a "$PACK/." "$DEST/"
rm -rf "$DEST/_deploy" "$DEST/MANIFEST"
bake "$DEST"
cp "$KIT/README.md" "$DEST/README.md"
for i in 0 1 2; do
  d="${OS_DIRS[$i]}"; e="${OS_EXTS[$i]}"
  mkdir -p "$DEST/$d"
  cp "$KIT/$d/README.md" "$DEST/$d/README.md"
  for b in "${BASES[@]}"; do
    cp "$KIT/$d/$b.$e" "$DEST/$d/$b.$e"
    case "$b.$e" in lib.*|*.cmd) chmod -x "$DEST/$d/$b.$e" ;; *) chmod +x "$DEST/$d/$b.$e" ;; esac
  done
done
{
  awk '/^APP_DIR=/ { exit } { print }' "$KIT/gitflow.conf"
  echo "APP_DIR=$(q "$APP_DIR")"
  echo "# Compose service of the app, and the port it listens on inside the container."
  echo "WEB_SERVICE=$(q "$WEB_SERVICE")"
  echo "APP_PORT=$(q "$APP_PORT")"
  echo
  echo "# Automated tests run on the host by finish_stage; empty = no automated tests."
  echo "TEST_CMD=$(q "$TEST_CMD")"
  echo "# Optional command run by dr_rebuild inside a throw-away container of the new image."
  echo "IMAGE_TEST_CMD=$(q "$IMAGE_TEST_CMD")"
  echo "# Language toolchain gitflow_init checks for (warnings only), space-separated."
  echo "REQUIRED_TOOLS=$(q "$REQUIRED_TOOLS")"
  echo
  sed -n '/^# Branch path policy/,$p' "$KIT/gitflow.conf"
} > "$DEST/gitflow.conf"
# LF everywhere for the scripts: a CRLF checkout (Windows autocrlf) would break them
{
  [ ! -s "$DEST/.gitattributes" ] || echo
  echo "# gitflow scripts and their settings keep LF line endings on every OS"
  echo "# (win/*.cmd files run their bash part through Git for Windows)"
  echo "*.sh   text eol=lf"
  echo "*.tool text eol=lf"
  echo "*.cmd  text eol=lf"
  echo "gitflow.conf text eol=lf"
  echo "VERSION text eol=lf"
} >> "$DEST/.gitattributes"

g() { git -C "$DEST" "$@"; }
git init -q "$DEST"
g symbolic-ref HEAD refs/heads/master
g config user.name "$GNAME"; g config user.email "$GMAIL"
g add -A
g commit -q -m "$PACK_V init: starter pack"
g log -1 --format='  %h %s'

info "deploy"
g checkout -q -b deploy
OVL="$(mktemp -d)"; cp -a "$PACK/_deploy/." "$OVL/"; bake "$OVL"; cp -a "$OVL/." "$DEST/"; rm -rf "$OVL"
DV="$(bump_patch "$PACK_V")"; echo "$DV" > "$DEST/VERSION"
g add -A
g commit -q -m "$DV init deploy branch: prod compose"
g log -1 --format='  %h %s'
g checkout -q master

info "GitHub"
confirm "Create $REPO on GitHub and push master + deploy?" || { echo "local repository kept in $DEST — nothing created on GitHub"; exit 0; }
gh repo create "$REPO" "--$VIS" --description "$DESC" >/dev/null
if [ "$PROTO" = ssh ]; then URL="git@github.com:$REPO.git"; else gh auth setup-git; URL="https://github.com/$REPO.git"; fi
g remote add origin "$URL"
g push -q -u origin master deploy
gh api -X PATCH "repos/$REPO" -f default_branch=master -F allow_merge_commit=true \
  -F allow_squash_merge=false -F allow_rebase_merge=false \
  -f merge_commit_title=PR_TITLE -f merge_commit_message=PR_BODY >/dev/null \
  && echo "merge settings: merge commits only, title = PR title" || warn "could not change the merge settings — set them in Settings -> General"
for u in ${COLLABS[@]+"${COLLABS[@]}"}; do
  gh api -X PUT "repos/$REPO/collaborators/$u" -f permission=push >/dev/null \
    && echo "invited $u" || warn "could not invite $u"
done
gh api -X PUT "repos/$REPO/branches/master/protection" --input - >/dev/null 2>&1 <<'JSON' \
  && echo "master: pull requests required" \
  || warn "branch protection refused (GitHub requires a paid plan for private repositories) — master is protected by convention only"
{"required_status_checks": null, "enforce_admins": false,
 "required_pull_request_reviews": {"required_approving_review_count": 0}, "restrictions": null}
JSON

info "done: https://github.com/$REPO"
cat <<EOF
Hand every developer the folder for their OS — linux/, macos/ or win/ (its
gitflow_init and README.md$( [ "$VIS" = public ] && printf '; public repo: https://github.com/%s/tree/master' "$REPO")). They make a new
project folder, put that folder in it and run its gitflow_init there
(repository: $REPO).
Your own dev branch:  cd "$DEST" && linux/gitflow_init.sh --devname <your-nickname>
Invite more later:    gh api -X PUT repos/$REPO/collaborators/<login> -f permission=push
EOF
