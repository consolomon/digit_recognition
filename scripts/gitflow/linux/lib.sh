#!/usr/bin/env bash
# Shared helpers for the gitflow scripts in this folder (linux/ of a course
# repository). Sourced, never run:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Portable on purpose — bash 3.2 and BSD tools as well as GNU ones — because
# the macos/ and win/ copies run this same code. gf_root moves to the project
# root, so the paths below are relative to it (gitflow.conf, VERSION, ...).

# Git for Windows: its Unix tools first (no-op elsewhere)
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) PATH="/usr/bin:$PATH" ;; esac

GF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # the folder of these scripts
GF_CONF="${GF_CONF:-gitflow.conf}"

# ── output and prompts ───────────────────────────────────────────────────────
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# confirm "Question"  -> 0 on y/yes, 1 otherwise (EOF counts as no)
confirm() {
  local a="" re='^[Yy]([Ee][Ss])?$'
  read -r -p "$1 [y/N] " a || true
  [[ "$a" =~ $re ]]
}

# ask "Question" [default]  -> prints the answer (or the default)
ask() {
  local a=""
  read -r -p "$1${2:+ [$2]}: " a || true
  printf '%s\n' "${a:-${2:-}}"
}

# gf_help  -> print the calling script's help: its first block of # comments
gf_help() { awk '/^#!/ { next } /^#/ { s = 1; sub(/^# ?/, ""); print; next } s { exit }' "$0"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed${2:+ — $2}"; }

# ── repository ───────────────────────────────────────────────────────────────
# The project root is the clone these scripts sit in, wherever they are run from
gf_root() {
  local top
  top="$(git -C "$GF_DIR" rev-parse --show-toplevel 2>/dev/null)" \
    || die "$GF_DIR is not inside a clone of the course repository — join it with gitflow_init first"
  cd "$top" || die "cannot enter $top"
}

gf_load_conf() {
  APP_DIR="app"; WEB_SERVICE="web_server"; APP_PORT="8008"
  TEST_CMD=""; IMAGE_TEST_CMD=""; REQUIRED_TOOLS=""
  DEPLOY_OWNED=("docker-compose.yaml" ".gitignore"); DEV_ONLY=(); DEPLOY_KEEP=()
  # shellcheck source=/dev/null
  [ -f "$GF_CONF" ] && source "$GF_CONF"
  return 0
}

current_branch() { git symbolic-ref --short -q HEAD || true; }

devname() {
  local n
  n="$(git config --get gitflow.devname || true)"
  [ -n "$n" ] || die "no developer name in this clone — run linux/gitflow_init.sh --devname <name> first"
  printf '%s\n' "$n"
}

dev_branch() { printf 'dev/%s\n' "$(devname)"; }

tree_is_clean() { [ -z "$(git status --porcelain)" ]; }

require_clean_tree() {
  tree_is_clean && return 0
  git status --short
  die "uncommitted changes — commit or stash them first"
}

# ahead_behind <local> <remote>  -> "A B" (commits only on local, only on remote)
ahead_behind() { git rev-list --left-right --count "$1...$2" | awk '{print $1, $2}'; }

# ensure_pushed <branch>: local branch level with origin, offering the push when ahead
ensure_pushed() {
  local b="$1" a bh
  git fetch -q origin
  if ! git rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null; then
    confirm "$b is not on origin yet. Push it now?" || die "$b must be on origin first"
    git push -u origin "$b"; return 0
  fi
  read -r a bh <<< "$(ahead_behind "$b" "origin/$b")"
  [ "$bh" = 0 ] || die "$b is behind origin/$b by $bh commit(s) — pull it first (git pull --ff-only)"
  if [ "$a" != 0 ]; then
    confirm "$b is $a commit(s) ahead of origin. Push it now?" || die "$b must be pushed first"
    git push origin "$b"
  fi
}

# ── G.F.P versioning (F = stage number) ──────────────────────────────────────
VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

read_version() { tr -d '[:space:]' < VERSION; }

# vmax v1 v2 ...  -> the highest valid G.F.P among the arguments
vmax() { printf '%s\n' "$@" | tr -d '\r' | grep -E "$VERSION_RE" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1; }

# bump_patch G.F.P -> G.F.(P+1)
bump_patch() { local g f p; IFS=. read -r g f p <<< "$1"; printf '%s.%s.%s\n' "$g" "$f" "$((p + 1))"; }

# stage_version G.F.P N -> G.N.0
stage_version() { local g f p; IFS=. read -r g f p <<< "$1"; printf '%s.%s.0\n' "$g" "$2"; }

# resolve_version_conflict [git -C dir]: a conflicted VERSION takes the higher of both sides
resolve_version_conflict() {
  local g=(git "$@") ours theirs
  "${g[@]}" diff --name-only --diff-filter=U | grep -qxF VERSION || return 0
  ours="$("${g[@]}" show :2:VERSION 2>/dev/null | tr -d '[:space:]')"
  theirs="$("${g[@]}" show :3:VERSION 2>/dev/null | tr -d '[:space:]')"
  vmax "$ours" "$theirs" > "$("${g[@]}" rev-parse --show-toplevel)/VERSION"
  "${g[@]}" add VERSION
  echo "VERSION conflict resolved to the higher value: $(vmax "$ours" "$theirs")"
}

# ── path policy (gitflow.conf: DEPLOY_OWNED, DEV_ONLY, DEPLOY_KEEP) ─────────
# Arrays may be empty: bash 3.2 rejects "${a[@]}" of an empty array under
# set -u, so every such expansion is written ${a[@]+"${a[@]}"}.

# devonly_pathspec -> DEV_ONLY paths minus DEPLOY_KEEP, one pathspec per line
devonly_pathspec() {
  local p k
  [ "${#DEV_ONLY[@]}" -gt 0 ] || return 0
  for p in "${DEV_ONLY[@]}"; do printf '%s\n' "$p"; done
  for k in ${DEPLOY_KEEP[@]+"${DEPLOY_KEEP[@]}"}; do printf ':(exclude)%s\n' "$k"; done
}

# has_conflict_markers <worktree> <base ref>: the staged diff adds <<<<<<< / >>>>>>> lines
has_conflict_markers() { git -C "$1" diff --cached -U0 "$2" | grep -qE '^\+(<{7}|>{7})( |$)'; }
