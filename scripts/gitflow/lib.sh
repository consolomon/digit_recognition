#!/usr/bin/env bash
# Shared helpers for the gitflow *.sh scripts, which sit at the project root
# of a course repository. Sourced, never run:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Every script calls gf_root first, so all paths below are relative to the
# project root (gitflow.conf, VERSION, ...).

GF_CONF="${GF_CONF:-gitflow.conf}"

# ── output and prompts ───────────────────────────────────────────────────────
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# confirm "Question"  -> 0 on y/yes, 1 otherwise (EOF counts as no)
confirm() {
  local a=""
  read -r -p "$1 [y/N] " a || true
  [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ask "Question" [default]  -> prints the answer (or the default)
ask() {
  local a=""
  read -r -p "$1${2:+ [$2]}: " a || true
  printf '%s\n' "${a:-${2:-}}"
}

# gf_help  -> print the calling script's header comment (lines 2.. up to the first non-comment)
gf_help() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed${2:+ — $2}"; }

# ── repository ───────────────────────────────────────────────────────────────
gf_root() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
  cd "$top" || die "cannot enter $top"
}

gf_load_conf() {
  APP_DIR="app"; WEB_SERVICE="web_server"; APP_PORT="8008"
  TEST_CMD=""; IMAGE_TEST_CMD=""; REQUIRED_TOOLS=""
  DEPLOY_OWNED=("docker-compose.yaml" ".gitignore"); DEV_ONLY=(); DEPLOY_KEEP=()
  # shellcheck source=gitflow.conf
  [ -f "$GF_CONF" ] && source "$GF_CONF"
  return 0
}

current_branch() { git branch --show-current; }

devname() {
  local n
  n="$(git config --get gitflow.devname || true)"
  [ -n "$n" ] || die "no developer name in this clone — run ./gitflow_init.sh --devname <name> first"
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
vmax() { printf '%s\n' "$@" | grep -E "$VERSION_RE" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1; }

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
# devonly_pathspec -> DEV_ONLY paths minus DEPLOY_KEEP, one pathspec per line
devonly_pathspec() {
  local p k
  [ "${#DEV_ONLY[@]}" -gt 0 ] || return 0
  for p in "${DEV_ONLY[@]}"; do printf '%s\n' "$p"; done
  for k in "${DEPLOY_KEEP[@]}"; do printf ':(exclude)%s\n' "$k"; done
}

# has_conflict_markers <worktree> <base ref>: the staged diff adds <<<<<<< / >>>>>>> lines
has_conflict_markers() { git -C "$1" diff --cached -U0 "$2" | grep -qE '^\+(<{7}|>{7})( |$)'; }
