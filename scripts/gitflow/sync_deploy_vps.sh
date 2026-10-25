#!/usr/bin/env bash
# On the VPS: capture a hotfix made on the deploy checkout and back-port it.
#
#   scripts/gitflow/sync_deploy_vps.sh --master
#   scripts/gitflow/sync_deploy_vps.sh --dev
#   scripts/gitflow/sync_deploy_vps.sh --help
#
#   --master   back-port into master: branch hotfix/<VERSION> + pull request to master
#              (no dev branch is touched)
#   --dev      back-port into the dev/<dev> that deploy was last promoted from
#              (its "Promoted-From:" trailer), pushed directly; then offers a PR to master
#   --help     show this help
#
# Runs ONLY in the deploy checkout on the VPS. That checkout never changes
# branch and never hosts a merge: it only commits the hotfix and fast-forwards.
# Never force-pushes, rebases or resets.
#   A. local changes -> committed as a hotfix (version = highest VERSION on any
#      branch + 1 patch), pushed to deploy; a clean tree just fast-forwards
#   B. the hotfix commits (made on deploy since its last promote) are
#      cherry-picked in a temporary worktree onto the target; the target keeps
#      its own DEPLOY_OWNED / DEV_ONLY paths (scripts/gitflow/gitflow.conf).
#      Every collision asks: keep the hotfix side, keep the target side,
#      edit in $EDITOR, or abort.
#   C. shows the result, commits "<VERSION> back-port: <subject>", pushes (asks first)
#   D. prints the restart commands that apply (nothing is restarted for you)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE=""
for arg in "$@"; do
  case "$arg" in
    --master|--dev) [ -z "$MODE" ] || die "use exactly one of --master / --dev"; MODE="${arg#--}" ;;
    --help|-h) gf_help; exit 0 ;;
    *) gf_help >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { gf_help >&2; die "one of --master / --dev is required"; }

gf_root
gf_load_conf
GITDIR="$(git rev-parse --absolute-git-dir)"

# ── preflight ────────────────────────────────────────────────────────────────
info "preflight"
[ "$(current_branch)" = deploy ] || die "run this only in the deploy checkout on the VPS (current branch: $(current_branch)) — do not switch branches to comply"
for s in MERGE_HEAD CHERRY_PICK_HEAD REBASE_HEAD; do
  [ ! -e "$GITDIR/$s" ] || die "a git operation is in progress ($s) — finish or abort it first"
done
LEFTOVER="$(git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -E '/gf-sync\.[A-Za-z0-9]+$' || true)"
if [ -n "$LEFTOVER" ]; then
  echo "$LEFTOVER" | sed 's/^/  leftover worktree: /'
  confirm "An earlier run was interrupted. Remove the leftover worktree(s) and continue?" || die "stopped"
  while IFS= read -r w; do git worktree remove --force "$w" || true; done <<< "$LEFTOVER"
  git worktree prune
fi
START="$(git rev-parse HEAD)"
WT=""
cleanup() { if [ -n "$WT" ]; then git worktree remove --force "$WT" >/dev/null 2>&1 || true; rm -rf "$WT"; git worktree prune; fi; }
trap cleanup EXIT

git fetch -q origin || die "fetch failed"
ff_deploy() {
  local behind
  behind="$(git rev-list --count HEAD..origin/deploy)"
  [ "$behind" = 0 ] && return 0
  git pull -q --ff-only origin deploy || die "deploy has diverged from origin/deploy — reconcile by hand (never merge, rebase or force-push here)"
  echo "fast-forwarded $behind commit(s):"; git log --format='  %h %s' "$START..HEAD"
}

# ── A. hotfix capture ────────────────────────────────────────────────────────
if tree_is_clean; then
  info "A. clean tree — sync with origin/deploy"
  ff_deploy
else
  info "A. local changes — capture them as a hotfix"
  git status --short
  echo "ignored (stay out of git):"; git status --short --ignored | sed -n 's/^!! /  /p'
  CHANGED="$(git status --porcelain | cut -c4- | sed 's/.* -> //')"
  BAD="$(echo "$CHANGED" | grep -E '^"?nginx/certbot/' || true)"
  [ -z "$BAD" ] || die "certificate/private-key paths are not ignored: $BAD — fix .gitignore, never commit them"
  SECRET="$(echo "$CHANGED" | grep -iE '(^|/)(id_rsa|id_ed25519)|\.(pem|key|p12|pfx)$|(^|/)\.env\.|secret|token|passw' || true)"
  if [ -n "$SECRET" ]; then
    echo "$SECRET" | sed 's/^/  secret-looking: /'
    confirm "These paths look like secrets (keys, tokens, passwords). Are you sure they belong in git?" || die "move them out of the change set first"
  fi
  PATHS=()
  if ! confirm "Commit ALL the changes above as the hotfix?"; then
    read -r -a PATHS <<< "$(ask "Paths that belong to the hotfix (space-separated)")"
    [ "${#PATHS[@]}" -gt 0 ] || die "no paths given"
  fi
  ff_deploy
  V="$(bump_patch "$(vmax "$(read_version)" "$(git for-each-ref --format='%(refname)' refs/remotes/origin \
        | grep -v '/HEAD$' | while IFS= read -r r; do git show "$r:VERSION" 2>/dev/null; done)")")"
  SUBJECT="$(ask "Subject for this VPS hotfix" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*//')"
  [ -n "$SUBJECT" ] || die "a subject is required"
  echo "$V" > VERSION
  if [ "${#PATHS[@]}" -gt 0 ]; then git add -- "${PATHS[@]}" VERSION; else git add -A; fi
  git commit -q -m "$V $SUBJECT"
  git log -1 --format='hotfix: %h %s'
  confirm "Push the hotfix to origin/deploy?" || die "hotfix committed locally but not pushed — push it, then re-run"
  git push origin deploy || die "push rejected — fetch, check, re-run"
  git fetch -q origin
fi
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/deploy)" ] || die "deploy is not level with origin/deploy"

# ── B. back-port ─────────────────────────────────────────────────────────────
# Hotfix commits: deploy's own non-merge commits since its last promote.
HOTFIXES=(); PROMOTED_FROM=""
while IFS= read -r sha; do
  body="$(git log -1 --format=%B "$sha")"
  if grep -q '^Promoted-From: ' <<< "$body"; then
    PROMOTED_FROM="$(sed -n 's/^Promoted-From: //p' <<< "$body" | head -n 1)"; break
  fi
  if [ "$(git rev-list --parents -n 1 "$sha" | wc -w)" -eq 2 ]; then HOTFIXES=("$sha" "${HOTFIXES[@]}"); fi
done < <(git rev-list --first-parent HEAD)

if [ "$MODE" = dev ]; then
  [ -n "$PROMOTED_FROM" ] || die "deploy was never promoted from a dev branch — use --master"
  git rev-parse -q --verify "refs/remotes/origin/$PROMOTED_FROM" >/dev/null || die "origin/$PROMOTED_FROM no longer exists — use --master"
  TARGET="origin/$PROMOTED_FROM"; LABEL="$PROMOTED_FROM"
else
  TARGET="origin/master"; LABEL="master"
fi

info "B. back-port into $LABEL"
if [ "${#HOTFIXES[@]}" -eq 0 ]; then
  echo "no hotfix commits on deploy since its last promote — nothing to back-port"
else
  echo "hotfix commits (oldest first):"; for h in "${HOTFIXES[@]}"; do git log -1 --format='  %h %s' "$h"; done

  WT="$(mktemp -d "${TMPDIR:-/tmp}/gf-sync.XXXXXX")"
  git worktree add -q --detach "$WT" "$TARGET"
  w() { git -C "$WT" "$@"; }

  # resolve every unmerged path: ours = the target, theirs = the hotfix
  resolve_collisions() {
    local f st kind a tries files
    # list first: the prompts below must read the keyboard, not this list
    mapfile -t files < <(w diff --name-only --diff-filter=U)
    for f in "${files[@]}"; do
      [ -n "$f" ] || continue
      st="$(w ls-files -u -- "$f" | awk '{print $3}' | sort -u | tr -d '\n')"
      case "$st" in 123) kind="changed on both";; 13) kind="deleted on $LABEL, changed by the hotfix";;
                    12) kind="changed on $LABEL, deleted by the hotfix";; 23) kind="added on both";; *) kind="stages $st";; esac
      echo; echo "COLLISION: $f ($kind)"
      w diff -- "$f" | head -n 40
      tries=0
      while :; do
        a="$(ask "[h] keep the hotfix side  [t] keep $LABEL's side  [e] edit in \$EDITOR  [a] abort" "")"
        case "$a" in
          "") tries=$((tries + 1)); [ "$tries" -lt 3 ] || die "no answer — aborted, nothing was pushed to $LABEL" ;;
          h) if [[ "$st" == *3* ]]; then w checkout --theirs -- "$f"; w add -- "$f"; else w rm -q -- "$f"; fi; break ;;
          t) if [[ "$st" == *2* ]]; then w checkout --ours -- "$f"; w add -- "$f"; else w rm -q -- "$f"; fi; break ;;
          e) "${EDITOR:-vi}" "$WT/$f"
             if grep -qE '^(<{7}|>{7}|={7})( |$)' "$WT/$f"; then echo "conflict markers are still in $f"; else w add -- "$f"; break; fi ;;
          a) die "aborted — nothing was pushed to $LABEL" ;;
        esac
      done
    done
  }

  mapfile -t DEVONLY < <(devonly_pathspec)
  APPLIED=()
  for h in "${HOTFIXES[@]}"; do
    before="$(w write-tree)"
    w -c merge.conflictStyle=diff3 cherry-pick --no-commit "$h" >/dev/null 2>&1 || true
    # the target keeps its own deploy-owned (+ .gitignore) and dev-only paths
    for p in "${DEPLOY_OWNED[@]}" .gitignore; do
      w rm -r -q -f --ignore-unmatch -- "$p"
      if [ -n "$(git ls-tree -r --name-only "$TARGET" -- "$p")" ]; then w checkout "$TARGET" -- "$p"; fi
    done
    if [ "${#DEVONLY[@]}" -gt 0 ]; then
      w rm -r -q -f --ignore-unmatch -- "${DEVONLY[@]}"
      w checkout "$TARGET" -- "${DEVONLY[@]}" 2>/dev/null || true
    fi
    w checkout "$TARGET" -- VERSION 2>/dev/null || true      # set once, below
    resolve_collisions
    w cherry-pick --quit 2>/dev/null || true
    # a hotfix the target already has (an earlier back-port) changes nothing
    if [ "$(w write-tree)" != "$before" ]; then APPLIED+=("$h"); fi
  done
  V="$(vmax "$(git show "$TARGET:VERSION")" "$(git show HEAD:VERSION)")"
  echo "$V" > "$WT/VERSION"; w add VERSION

  [ -z "$(w diff --name-only --diff-filter=U)" ] || die "unmerged paths remain"
  ! has_conflict_markers "$WT" "$TARGET" || die "conflict markers are staged"
  if [ "${#APPLIED[@]}" -eq 0 ] || w diff --cached --quiet "$TARGET" -- . ":(exclude)VERSION"; then
    echo "$LABEL already has these hotfixes — nothing to back-port"
  else
    # ── C. commit and publish ────────────────────────────────────────────────
    info "C. $LABEL will receive"
    w diff --cached --stat "$TARGET" | tail -n 25
    FIRST="$(git log -1 --format=%s "${APPLIED[0]}" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*//')"
    MORE=""; [ "${#APPLIED[@]}" -gt 1 ] && MORE=" (+$(( ${#APPLIED[@]} - 1 )) more)"
    w commit -q -m "$V back-port: $FIRST$MORE" -m "$(for h in "${APPLIED[@]}"; do git log -1 --format='(cherry picked from commit %H)' "$h"; done)"
    w log -1 --format='back-port: %h %s'
    REPO_URL="$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')"
    if [ "$MODE" = dev ]; then
      confirm "Push the back-port to $PROMOTED_FROM?" || die "not pushed — nothing changed on origin"
      w push origin "HEAD:refs/heads/$PROMOTED_FROM" || die "push rejected ($PROMOTED_FROM moved meanwhile) — re-run"
      echo "pushed to $PROMOTED_FROM — its developer should git pull before new work"
      PR_HEAD="$PROMOTED_FROM"
      confirm "Open a pull request $PROMOTED_FROM -> master as well?" || PR_HEAD=""
    else
      HB="hotfix/$V"
      ! git rev-parse -q --verify "refs/remotes/origin/$HB" >/dev/null || die "origin already has $HB"
      confirm "Push the back-port as $HB and open a pull request to master?" || die "not pushed — nothing changed on origin"
      w push origin "HEAD:refs/heads/$HB" || die "push of $HB rejected"
      PR_HEAD="$HB"
    fi
    if [ -n "$PR_HEAD" ]; then
      if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        gh pr create --base master --head "$PR_HEAD" --title "$V merge: $PR_HEAD → master" \
          --body "VPS hotfix back-port by scripts/gitflow/sync_deploy_vps.sh --$MODE." || warn "gh pr create failed — open it by hand"
      else
        echo "gh not available — open the pull request in the browser: $REPO_URL/compare/master...$PR_HEAD"
      fi
    fi
  fi
fi

# ── D. what to restart (reminder only) ───────────────────────────────────────
info "D. since $(git rev-parse --short "$START") — run what applies"
CH="$(git diff --name-only "$START" HEAD)"
any=""
if grep -q "^$APP_DIR/" <<< "$CH"; then echo "  $APP_DIR/ changed:                docker compose up -d --build $WEB_SERVICE"; any=1; fi
if grep -q '^nginx/' <<< "$CH"; then echo "  nginx/ changed:                docker compose up -d --force-recreate nginx"; any=1; fi
if grep -qx 'docker-compose.yaml' <<< "$CH"; then echo "  docker-compose.yaml changed:   docker compose up -d --build"; any=1; fi
if [ -n "$any" ]; then echo "  then verify end to end:        scripts/gitflow/dr_rebuild.sh --check-only"; else echo "  nothing to restart"; fi
echo
echo "master is only changed through pull requests; tell the team if a dev branch moved."
