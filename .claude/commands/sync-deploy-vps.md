---
description: On the VPS — sync deploy both ways (capture VPS hotfixes, back-port into dev, promote dev into deploy) with a dialog for every collision
---

Sync the VPS `deploy` branch both ways: capture VPS hotfixes (or pull `origin/deploy`), then back-port `deploy` into `origin/dev` and promote `origin/dev` into `deploy`, with a dialog for every collision.

Adapted on 2026-10-17 from Sreda-obitaniya's `/sync-deploy-vps` (verified
there by a 145-check offline harness and production runs). **Runs on the
VPS only**, in the production checkout (`deploy`), started from a Claude Code
session there (`resources/documentation/DEPLOY_INIT.md` §"Claude Code on the
VPS"). It is the one sanctioned exception to the rule that branch management
happens on the dev PC (`GITFLOW.md` §"VPS hotfixes"). It exists so VPS-side
hotfixes are never lost or left to drift, and so the two long-lived branches
stay reconciled without a round trip through the dev PC. It touches **only**
`deploy` and `dev`, never `master` or any `feature/*` branch.

## Hard rules

- **The production checkout never changes branch and never hosts a merge.** Both
  merges run in temporary git worktrees under `${TMPDIR:-/tmp}`. The checkout at
  the project root only ever receives a `git pull --ff-only` or a
  `git merge --ff-only`, which rewrites nothing but the files that actually
  differ — the running stack's bind mounts (`nginx/templates`,
  `nginx/certbot/`) and build context are never half-merged.
- **Never force-push, rebase, or `reset --hard`.** On any divergence or rejected
  push, stop and report.
- **`dev` is pushed only together with `deploy`, atomically** (`git push --atomic`),
  and only when a back-port commit exists. Either both refs move or neither does.
  A back-port left on `dev` without its matching promote would flip deploy's
  owned paths (`DEPLOY_OWNED`, `.gitignore`) onto dev's side of the ancestry,
  and the next dev-PC promotion could no longer tell which side owns them.
- **Nothing is pushed without explicit approval** in the final dialog. Silence
  is not approval, and neither is an earlier approval from a previous run.
- **Every commit message is exactly the message given**, `G.F.P`-prefixed per
  `CLAUDE.md` §"Commit message versioning": no `Co-Authored-By: Claude`
  trailer, no `Generated with Claude Code` footer, no `Claude-Session` link
  (`CLAUDE.md` §"No Claude authorship"). This covers the hotfix, back-port
  and promote commits alike.
- Run every block **verbatim** from the project root, replacing only
  `__MESSAGE__` where a block has it. Never `cd` (`CLAUDE.md`); the blocks use
  `git -C`.

## Path policy

| Class | Paths | Back-port (deploy → dev) | Promote (dev → deploy) |
|---|---|---|---|
| Deploy-owned | the `DEPLOY_OWNED` array in `scripts/merge_to_deploy.sh` (today: `docker-compose.yaml`) | dev's own version (absent if dev has none) | deploy's own version, always |
| `.gitignore` | `.gitignore` | dev's file, plus only the deploy lines chosen in a dialog | deploy's own version, always |
| Dev-only | the `DEV_ONLY` array (today: `resources`), minus `DEPLOY_KEEP` | dev's own version | removed from the index **and** the worktree |
| `DEPLOY_KEEP` | the `DEPLOY_KEEP` array | ordinary 3-way merge | ordinary 3-way merge |
| `VERSION` | `VERSION` | the higher of the two values | dev's (the back-port's) value |
| Everything else | `app/`, `nginx/`, `.env`, `CLAUDE.md`, `tests/`, `.claude/`, `scripts/` | ordinary 3-way merge | ordinary 3-way merge |

The three arrays are read from `scripts/merge_to_deploy.sh` at run time, so
the script stays the single source of truth. Both apply git's 3-way merge to
`DEPLOY_KEEP` paths, so edits made on either branch survive.

"Deploy-owned always restored" also covers the ancestry flip. After any
back-port, git sees dev's side of those paths as dev's changes. Restoring them
unconditionally, rather than only on a conflict, is what keeps production intact.

**Versions.** A VPS hotfix is a normal commit: it bumps P from the highest
`VERSION` on either branch (`hotfix-version` prints it), so it never reuses a
number dev already has. The back-port and the promote are merge commits and
carry the version forward unchanged (`CLAUDE.md`): their messages start with
the `VERSION` the merge produced.

## Part A: sync with `origin/deploy`

1. Run the `preflight` block. If the branch is not exactly `deploy`, stop and warn,
   and do not switch branches to comply. If it reports a merge in progress, leftover
   state or a leftover `sync-dev.*` / `sync-deploy.*` worktree, an earlier run was
   interrupted. Ask whether to clean it up (run `cleanup`, then start again) or
   stop.
2. Run `state-init`. It records the starting commit, which Part D uses to decide
   what needs redeploying.
3. Run `git status --short`.
   - **Clean tree:** run `git fetch origin deploy`, then
     `git rev-list HEAD..origin/deploy --count`. If the count is greater than 0, run
     `git pull --ff-only origin deploy`. If the fast-forward fails (the branches
     have diverged), stop and warn the user to reconcile manually; never merge,
     rebase or force-push to resolve it. After a pull, list the new commits one
     line each. Then go to Part B. Do not offer a redeploy here; Part D does it
     once, for the whole run.
   - **Local changes:** capture them as a hotfix first.
     a. Subject: the text given after `/sync-deploy-vps` (`$ARGUMENTS`),
        otherwise ask: "Enter the subject for this VPS hotfix:". The version
        is computed, never typed — if the subject starts with a `G.F.P`, drop
        it and say so.
     b. `git fetch origin deploy`, then `git rev-list HEAD..origin/deploy --count`.
        If greater than 0, run `git pull --ff-only origin deploy`. On divergence,
        stop and warn, as above.
     c. Show `git status --short` and `git status --short --ignored` before
        staging anything. `nginx/certbot/` (certificates and **private keys**)
        must stay ignored. `.env` is tracked by design but must never hold a
        secret — if the diff adds one (a key, token, password), stop and ask.
        If anything secret-looking is untracked and about to be swept in, stop
        and ask. If the tree also holds changes that are not part of this
        hotfix (untracked files, or someone's work in progress), ask which
        paths belong to it and stage those explicitly instead of `git add -A`.
        The rest stay uncommitted; `publish` refuses only if its fast-forward
        would update one of them.
     d. Run `hotfix-version`, write the printed version into `VERSION`
        (`echo "<version>" > VERSION`), then `git add -A` (or the explicit
        paths, plus `VERSION`) and `git commit -m "<version> <subject>"`.
        The message is exact (see Hard rules).
     e. `git push origin deploy`, and report the hash and message.
     f. Go to Part B.

## Part B: back-port `deploy` into `origin/dev`

4. Run `plan`. It fetches `deploy` and `dev`, stops unless `deploy` is level with
   `origin/deploy`, reads the path policy, and lists the commits on each side.
   - Both counts 0: the branches are in sync. Go to Part D.
   - `on deploy, not on dev` is 0: skip to step 9 (promote from `origin/dev`).
5. Run `backport-prepare`. It creates the dev worktree (`WT_DEV`) at `origin/dev`,
   merges `deploy` into it without committing, and applies the back-port column of
   the policy (including `VERSION`). It then lists:
   - **collisions needing a decision**: resolve each through the collision
     dialogs below. In `WT_DEV`, **ours = dev and theirs = deploy**.
   - **deploy .gitignore lines dev does not have**: ask one multiSelect question
     listing them. Lines tagged `ignores a dev-only path` exist on deploy by
     design and are recommended **not** to carry, because they would make dev
     ignore files it tracks. For each chosen line run
     `printf '%s\n' '<line>' >> "$WT_DEV/.gitignore"`, then
     `git -C "$WT_DEV" add .gitignore`. Choosing none is valid. Skip the question
     if every line is tagged.
6. Run `backport-verify`. Every check must be `[ok]`. On a `[FAIL]`, fix the
   cause in `WT_DEV` and run it again, or abort (run `cleanup`). Nothing has been
   pushed yet.
   - `BACKPORT=empty`: deploy has nothing dev lacks (for example only earlier
     promote merges). Run `backport-discard` and go to step 9.
   - `BACKPORT=content`: go to step 7.
7. The back-port commit message is `<VERSION> merge: back-port deploy into dev`,
   with the version `backport-verify` printed (carry-forward). Offer it; "Other"
   takes a custom subject, but the version prefix stays.
8. Run `backport-commit` with that message. The commit exists only in `WT_DEV`
   and is pushed in step 12, or never.

## Part C: promote into `deploy` and publish

9. Run `promote-prepare`. It creates the deploy worktree (`WT_DEPLOY`) at the
   current `deploy` commit and merges the back-port commit into it (or
   `origin/dev` when there is none), without committing. It then applies the
   promote column of the policy. **When a back-port commit exists this promote is
   mandatory**, even if it changes no files: it is what puts deploy's owned
   paths back on deploy's side of the ancestry. If the block exits with
   `NOTHING TO PROMOTE`, go to Part D.
   - **dev's own commits that edit deploy-owned paths**: for each path, show the
     patch (`git show <sha> -- <path>`) and ask: *Keep deploy's version
     (Recommended)*, *Port the change into deploy's file* or *Abort*. To port,
     edit the file in `WT_DEPLOY` by hand, run `git -C "$WT_DEPLOY" add -- <path>`,
     and record it with
     `echo 'PORTED+=(<top-level path, e.g. docker-compose.yaml>)' >> "$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"`.
   - **collisions needing a decision**: resolve through the collision dialogs. In
     `WT_DEPLOY`, **ours = deploy and theirs = dev**. After a back-port there
     should be none, because every collision was settled in step 5.
10. Run `promote-verify`. Every check must be `[ok]` (fix or abort, as in step 6).
11. The final dialog. Show:
    - the back-port commit, if any: `git -C "$WT_DEV" log -1 --format='%h %s'`
      and `git diff --stat origin/dev "$BACKPORT_SHA"` (what `dev` gains);
    - the net change production will receive:
      `git -C "$WT_DEPLOY" diff --cached --stat "$PRE_PROMOTE"`;
    - what will be pushed: both refs atomically, or `deploy` alone.
    Ask two questions in one dialog: the promote message (offer
    `<VERSION> merge: promote the back-port to deploy`, or
    `<VERSION> merge: sync dev → deploy` when there is no back-port, with the
    version `promote-verify` printed), and *Commit and push* versus *Abort
    everything*. On abort, run `cleanup`. Nothing has been pushed and the
    production checkout is untouched.
12. Run `promote-commit` with the message, then `publish`. `publish` refuses if
    `deploy` moved, if an uncommitted change sits in a file the fast-forward
    would update, or if an untracked file sits where it would write. Unrelated
    work in progress elsewhere in the checkout is left alone. It pushes, then
    fast-forwards the production checkout.
    - `STOP: local changes in files the fast-forward would update`: nothing was
      pushed. Committing, stashing or discarding those changes is the user's
      decision. Then `cleanup` and start again.
    - `PUSH REJECTED`: someone pushed in the meantime. Neither ref moved and the
      checkout is untouched. Run `cleanup` and start the skill again.
    - `STOP: untracked files would be overwritten`: nothing was pushed. Show the
      files. Moving them aside is the user's decision. Then `cleanup` and start
      again.

## Part D: redeploy offer and cleanup

13. Run `impact`. It compares the starting commit with the final one:
    - `REBUILD WEB_SERVER`: offer `docker compose up -d --build web_server`.
    - `RECREATE NGINX`: offer `docker compose up -d --force-recreate nginx`
      (templates are rendered only at container start; also needed when
      `.env` changed `DOMAIN`).
    - `COMPOSE CHANGED`: offer `docker compose up -d --build`.
    **Wait for explicit approval before running anything**, since each one
    restarts a live container. After any redeploy, run `e2e` — the request a
    user makes, through nginx; `docker compose ps` alone proves nothing.
14. Run `cleanup`. It removes both worktrees and the state file, and must leave
    `git worktree list` showing only the project root.
15. Report: every commit made (hash and exact message), that `deploy` is `0 0`
    with `origin/deploy`, and whether `origin/dev` now points at the back-port.
    Remind the user that `master` is not touched by this skill (promote it on the
    dev PC), and, if `dev` moved, to `git pull` it on the dev PC (and to tell any
    open feature sessions) before new work.

## Collision dialogs

Resolve every path the prepare block listed before running its verify block.
Batch at most four paths per dialog, one question per path. For each, show the
conflict kind, the commits that touched it on each side since the merge base
(`git log --oneline "$MB..$DEPLOY_SHA" -- <path>` and
`git log --oneline "$MB..origin/dev" -- <path>`), and a short preview of the
conflicting hunks (`git -C <worktree> diff -- <path>`; the merges use diff3, so
the `|||||||` section is the merge base).

Options per path: *Keep deploy's version*, *Keep dev's version*, *Hunk by hunk*
(text files only), *Abort the whole sync*.

| Decision | in `WT_DEV` (ours = dev) | in `WT_DEPLOY` (ours = deploy) |
|---|---|---|
| Keep deploy's version | `git -C "$WT_DEV" checkout --theirs -- <path>` | `git -C "$WT_DEPLOY" checkout --ours -- <path>` |
| Keep dev's version | `git -C "$WT_DEV" checkout --ours -- <path>` | `git -C "$WT_DEPLOY" checkout --theirs -- <path>` |
| Keep the side that deleted it | `git -C <worktree> rm -q -- <path>` | same |

Follow every checkout with `git -C <worktree> add -- <path>`.

**Hunk by hunk:** read the file from the worktree and ask one question per
conflict block (at most four per dialog). Previews show dev's side, deploy's side
and the base. Options: *deploy's side*, *dev's side*, *both, deploy's first*,
*both, dev's first*; "Other" takes replacement text. Apply each answer with the
Edit tool on the worktree file, then `git -C <worktree> add -- <path>`. Never
leave a conflict marker behind; the verify blocks fail on one.

**Abort:** run `cleanup`. Before step 12 nothing has been pushed and the
production checkout has not changed.

## Blocks

```bash
# block: preflight
set -uo pipefail
GITDIR="$(git rev-parse --absolute-git-dir)"
echo "branch: $(git branch --show-current)"
if [ -f "$GITDIR/MERGE_HEAD" ]; then echo "MERGE IN PROGRESS: $(git rev-parse --short MERGE_HEAD)"; else echo "no merge in progress"; fi
if [ -f "$GITDIR/sync-deploy-vps.env" ]; then echo "LEFTOVER STATE: $GITDIR/sync-deploy-vps.env"; else echo "no leftover state"; fi
git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -E '/sync-(dev|deploy)\.[A-Za-z0-9]+$' | sed 's/^/LEFTOVER WORKTREE: /'
git status --short
```

```bash
# block: state-init
set -euo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"
echo "START=$(git rev-parse HEAD)" > "$STATE"
echo "run started at $(git log -1 --format='%h %s')"
```

```bash
# block: hotfix-version
set -uo pipefail
git fetch -q origin deploy dev || { echo "STOP: fetch failed"; exit 1; }
V="$( { cat VERSION; git show HEAD:VERSION; git show origin/deploy:VERSION; git show origin/dev:VERSION; } 2>/dev/null \
  | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
IFS=. read -r va vb vc <<< "${V:-0.0.0}"
echo "highest VERSION on deploy/dev: ${V:-none}; hotfix version: $va.$vb.$((vc+1))"
```

```bash
# block: plan
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
git fetch -q origin deploy dev || { echo "STOP: fetch failed"; exit 1; }
if [ "$(git rev-list --left-right --count HEAD...origin/deploy)" != "$(printf '0\t0')" ]; then
  echo "STOP: deploy is not level with origin/deploy -- finish Part A first"; exit 1
fi
arr() { sed -n "/^$1=(/,/^)/{/^$1=(/d;/^)/d;s/#.*//;s/^[[:space:]]*//;s/[[:space:]]*\$//;s/^\"//;s/\"\$//;/^\$/d;p;}" scripts/merge_to_deploy.sh; }
mapfile -t KEEP < <(arr DEPLOY_KEEP)
mapfile -t STRIP < <(arr DEV_ONLY)
mapfile -t OWNED < <(arr DEPLOY_OWNED)
if [ "${#KEEP[@]}" -eq 0 ] || [ "${#OWNED[@]}" -eq 0 ] || ! printf '%s\n' "${STRIP[@]}" | grep -qx resources; then
  echo "STOP: could not read DEPLOY_KEEP, DEV_ONLY and DEPLOY_OWNED from scripts/merge_to_deploy.sh"; exit 1
fi
DEVONLY=("${STRIP[@]}"); for k in "${KEEP[@]}"; do DEVONLY+=(":(exclude)$k"); done
MB="$(git merge-base HEAD origin/dev)"
TO_DEV="$(git rev-list --count origin/dev..HEAD)"
TO_DEPLOY="$(git rev-list --count HEAD..origin/dev)"
{ declare -p KEEP STRIP OWNED DEVONLY; echo "MB=$MB"; echo "TO_DEV=$TO_DEV"; echo "TO_DEPLOY=$TO_DEPLOY"; echo "PORTED=()"; } >> "$STATE"
echo "policy: DEPLOY_KEEP=${KEEP[*]}"
echo "        dev-only=${STRIP[*]}"
echo "        deploy-owned=${OWNED[*]} .gitignore"
echo "merge base: $(git log -1 --format='%h %s' "$MB")"
echo "VERSION: deploy $(git show HEAD:VERSION), dev $(git show origin/dev:VERSION)"
echo "--- on deploy, not on dev ($TO_DEV) ---"; git log --format='%h %s' origin/dev..HEAD | head -n 40
echo "--- on dev, not on deploy ($TO_DEPLOY) ---"; git log --format='%h %s' HEAD..origin/dev | head -n 40
```

```bash
# block: backport-prepare
set -uo pipefail
GITDIR="$(git rev-parse --absolute-git-dir)"; STATE="$GITDIR/sync-deploy-vps.env"; source "$STATE"
WT_DEV="$(mktemp -d "${TMPDIR:-/tmp}/sync-dev.XXXXXX")"
DEPLOY_SHA="$(git rev-parse HEAD)"
{ echo "WT_DEV=$WT_DEV"; echo "DEPLOY_SHA=$DEPLOY_SHA"; } >> "$STATE"
git worktree add -q --detach "$WT_DEV" origin/dev || { echo "STOP: could not create the dev worktree"; exit 1; }
d() { git -C "$WT_DEV" "$@"; }
d -c merge.conflictStyle=diff3 merge --no-ff --no-commit "$DEPLOY_SHA" 2>&1 | grep -E '^(CONFLICT|Automatic merge|Already up to date)' || true
# deploy-owned paths: drop whatever the merge staged, put back dev's own copy if dev has one
for p in "${OWNED[@]}"; do
  d rm -r -q -f --ignore-unmatch -- "$p"
  if [ -n "$(git ls-tree -r --name-only origin/dev -- "$p")" ]; then d checkout origin/dev -- "$p"; fi
done
# dev-only paths: back to dev's own copy (DEPLOY_KEEP excluded -- those keep the 3-way merge)
d rm -r -q -f --ignore-unmatch -- "${DEVONLY[@]}"
EX=(); for k in "${KEEP[@]}"; do EX+=(":(exclude)$k"); done
for s in "${STRIP[@]}"; do d checkout origin/dev -- "$s" "${EX[@]}" 2>/dev/null || true; done
# VERSION: the higher of the two values (a VPS hotfix is always the higher one)
VD="$(git show origin/dev:VERSION)"; VP="$(git show "$DEPLOY_SHA:VERSION")"
VMAX="$(printf '%s\n%s\n' "$VD" "$VP" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
printf '%s\n' "$VMAX" > "$WT_DEV/VERSION"; d add VERSION
# .gitignore: dev's file; deploy's extra lines go to a dialog
d rm -q -f --ignore-unmatch -- .gitignore
if git cat-file -e origin/dev:.gitignore 2>/dev/null; then d checkout origin/dev -- .gitignore; fi
EXTRA="$GITDIR/sync-deploy-vps.gitignore-extra"
comm -13 <(git show origin/dev:.gitignore 2>/dev/null | sort -u) <(git show "$DEPLOY_SHA:.gitignore" 2>/dev/null | sort -u) | grep -v '^[[:space:]]*$' > "$EXTRA" || true
echo "--- deploy .gitignore lines dev does not have ---"
while IFS= read -r line; do
  tag=""; printf '%s\n' "${STRIP[@]}" | grep -qxF -- "${line%/}" && tag="   <- ignores a dev-only path; deploy-only by design"
  echo "  $line$tag"
done < "$EXTRA"
echo "--- collisions needing a decision (WT_DEV: ours = dev, theirs = deploy) ---"
d diff --name-only --diff-filter=U | while IFS= read -r f; do
  st="$(d ls-files -u -- "$f" | awk '{print $3}' | sort -u | tr -d '\n')"
  case "$st" in 123) k="both modified";; 13) k="deleted on dev, modified on deploy";; 12) k="modified on dev, deleted on deploy";; 23) k="added on both";; *) k="stages $st";; esac
  echo "  $f  ($k)"
done
echo "--- would land on dev (staged vs origin/dev) ---"; d diff --cached --name-status origin/dev
echo "WT_DEV=$WT_DEV"
```

```bash
# block: backport-verify
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
d() { git -C "$WT_DEV" "$@"; }
fail=0
check() { if [ -z "$2" ]; then echo "  [ok]   $1"; else echo "  [FAIL] $1"; printf '%s\n' "$2" | sed 's/^/         /'; fail=1; fi; }
check "no unmerged paths" "$(d diff --name-only --diff-filter=U)"
check "no conflict markers staged" "$(d diff --cached -U0 origin/dev | grep -E '^\+(<{7}|>{7})( |$)' | head -n 5)"
check "deploy-owned paths identical to origin/dev" "$(d diff --cached --name-status origin/dev -- "${OWNED[@]}")"
check "dev-only paths identical to origin/dev" "$(d diff --cached --name-status origin/dev -- "${DEVONLY[@]}")"
check "every back-ported path was changed on deploy since the merge base" \
  "$(comm -23 <(d diff --cached --name-only origin/dev | sort) <(git diff --name-only "$MB" "$DEPLOY_SHA" | sort) | grep -vx '.gitignore')"
echo "--- .gitignore vs origin/dev (only lines chosen in the dialog may appear) ---"
d diff --cached origin/dev -- .gitignore | grep -E '^[+-][^+-]' || echo "  (identical)"
echo "--- the back-port, as dev would receive it ---"; d diff --cached --stat origin/dev | tail -n 25
echo "carry-forward version for the back-port message: $(d show :VERSION)"
if d diff --cached --quiet origin/dev; then echo "BACKPORT=empty"; else echo "BACKPORT=content"; fi
exit "$fail"
```

```bash
# block: backport-discard
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
git worktree remove --force "$WT_DEV" && echo "removed $WT_DEV"
{ echo "WT_DEV="; echo "BACKPORT_SHA="; } >> "$STATE"
```

```bash
# block: backport-commit
set -euo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
MSG="$(cat <<'__EOF__'
__MESSAGE__
__EOF__
)"
git -C "$WT_DEV" commit -q -m "$MSG"
echo "BACKPORT_SHA=$(git -C "$WT_DEV" rev-parse HEAD)" >> "$STATE"
git -C "$WT_DEV" log -1 --format='back-port %h %s  (parents %p)'
```

```bash
# block: promote-prepare
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
SRC="${BACKPORT_SHA:-}"; [ -n "$SRC" ] || SRC="$(git rev-parse origin/dev)"
PRE_PROMOTE="$(git rev-parse HEAD)"
PMB="$(git merge-base "$PRE_PROMOTE" "$SRC")"
WT_DEPLOY="$(mktemp -d "${TMPDIR:-/tmp}/sync-deploy.XXXXXX")"
{ echo "SRC=$SRC"; echo "PRE_PROMOTE=$PRE_PROMOTE"; echo "PMB=$PMB"; echo "WT_DEPLOY=$WT_DEPLOY"; } >> "$STATE"
git worktree add -q --detach "$WT_DEPLOY" "$PRE_PROMOTE" || { echo "STOP: could not create the deploy worktree"; exit 1; }
p() { git -C "$WT_DEPLOY" "$@"; }
echo "--- dev's own (non-merge) commits that edit deploy-owned paths since $(git rev-parse --short "$PMB") ---"
git log --no-merges --format='%h %s' "$PMB..$SRC" -- "${OWNED[@]}" .gitignore
p -c merge.conflictStyle=diff3 merge --no-ff --no-commit "$SRC" 2>&1 | grep -E '^(CONFLICT|Automatic merge|Already up to date)' || true
p rev-parse -q --verify MERGE_HEAD >/dev/null || { echo "NOTHING TO PROMOTE: $SRC is already in deploy"; exit 3; }
# deploy-owned paths and .gitignore: deploy's own version, unconditionally (the ancestry flip)
for q in "${OWNED[@]}" .gitignore; do
  p rm -r -q -f --ignore-unmatch -- "$q"
  if [ -n "$(git ls-tree -r --name-only "$PRE_PROMOTE" -- "$q")" ]; then p checkout "$PRE_PROMOTE" -- "$q"; fi
done
# dev-only paths: out of the index and the worktree (DEPLOY_KEEP excluded)
p rm -r -q -f --ignore-unmatch -- "${DEVONLY[@]}"
# VERSION: the source's value (carry-forward, as scripts/merge_to_deploy.sh does)
p checkout "$SRC" -- VERSION && p add VERSION
echo "--- collisions needing a decision (WT_DEPLOY: ours = deploy, theirs = dev) ---"
p diff --name-only --diff-filter=U | while IFS= read -r f; do
  st="$(p ls-files -u -- "$f" | awk '{print $3}' | sort -u | tr -d '\n')"
  case "$st" in 123) k="both modified";; 13) k="deleted on deploy, modified on dev";; 12) k="modified on deploy, deleted on dev";; 23) k="added on both";; *) k="stages $st";; esac
  echo "  $f  ($k)"
done
echo "--- would change on deploy (staged vs deploy HEAD) ---"; p diff --cached --stat "$PRE_PROMOTE" | tail -n 25
echo "WT_DEPLOY=$WT_DEPLOY"
```

```bash
# block: promote-verify
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
p() { git -C "$WT_DEPLOY" "$@"; }
fail=0
check() { if [ -z "$2" ]; then echo "  [ok]   $1"; else echo "  [FAIL] $1"; printf '%s\n' "$2" | sed 's/^/         /'; fail=1; fi; }
check "no unmerged paths" "$(p diff --name-only --diff-filter=U)"
check "no conflict markers staged" "$(p diff --cached -U0 "$PRE_PROMOTE" | grep -E '^\+(<{7}|>{7})( |$)' | head -n 5)"
UNEXPECTED=""
while IFS= read -r f; do
  [ -z "$f" ] && continue; hit=""
  for q in "${PORTED[@]}"; do case "$f" in "$q"|"$q"/*) hit=1;; esac; done
  [ -z "$hit" ] && UNEXPECTED+="$f"$'\n'
done <<< "$(p diff --cached --name-only "$PRE_PROMOTE" -- "${OWNED[@]}" .gitignore)"
check "deploy-owned paths and .gitignore unchanged (except ported by decision)" "$UNEXPECTED"
check "no dev-only path in the index" "$(p ls-files -- "${DEVONLY[@]}")"
EXCL=(); for q in "${OWNED[@]}" .gitignore "${STRIP[@]}"; do EXCL+=(":(exclude)$q"); done
DIFF_APP="$(p diff --cached --name-status "$SRC" -- . "${EXCL[@]}")"
DIFF_KEEP="$(p diff --cached --name-status "$SRC" -- "${KEEP[@]}")"
if [ -n "${BACKPORT_SHA:-}" ]; then
  check "app paths identical to the back-port" "$DIFF_APP"
  check "DEPLOY_KEEP paths identical to the back-port" "$DIFF_KEEP"
else
  echo "--- deploy keeps these differences from origin/dev (each must be a collision resolved toward deploy) ---"
  printf '%s\n%s\n' "$DIFF_APP" "$DIFF_KEEP" | sed '/^$/d;s/^/  /'
fi
echo "--- net change production will receive ---"; p diff --cached --stat "$PRE_PROMOTE" | tail -n 25
echo "carry-forward version for the promote message: $(p show :VERSION)"
exit "$fail"
```

```bash
# block: promote-commit
set -euo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
MSG="$(cat <<'__EOF__'
__MESSAGE__
__EOF__
)"
git -C "$WT_DEPLOY" commit -q -m "$MSG"
echo "PROMOTE_SHA=$(git -C "$WT_DEPLOY" rev-parse HEAD)" >> "$STATE"
git -C "$WT_DEPLOY" log -1 --format='promote %h %s  (parents %p)'
```

```bash
# block: publish
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
[ "$(git rev-parse HEAD)" = "$PRE_PROMOTE" ] || { echo "STOP: deploy moved since the promote was prepared"; exit 1; }
CLASH="$(comm -12 <(git -c core.quotepath=false diff --name-only HEAD | sort) <(git -c core.quotepath=false diff --name-only "$PRE_PROMOTE" "$PROMOTE_SHA" | sort))"
[ -z "$CLASH" ] || { echo "STOP: local changes in files the fast-forward would update:"; printf '%s\n' "$CLASH" | sed 's/^/  /'; exit 1; }
BLOCKERS="$(git -c core.quotepath=false diff --name-only --diff-filter=A "$PRE_PROMOTE" "$PROMOTE_SHA" | while IFS= read -r f; do [ -e "$f" ] && echo "$f"; done)"
[ -z "$BLOCKERS" ] || { echo "STOP: untracked files would be overwritten by the fast-forward:"; printf '%s\n' "$BLOCKERS" | sed 's/^/  /'; exit 1; }
if [ -n "${BACKPORT_SHA:-}" ]; then
  git push --atomic origin "$BACKPORT_SHA:refs/heads/dev" "$PROMOTE_SHA:refs/heads/deploy" || { echo "PUSH REJECTED: neither dev nor deploy was updated"; exit 2; }
else
  git push origin "$PROMOTE_SHA:refs/heads/deploy" || { echo "PUSH REJECTED: deploy was not updated"; exit 2; }
fi
git merge -q --ff-only "$PROMOTE_SHA" || { echo "STOP: pushed, but the fast-forward of the production checkout failed -- run: git pull --ff-only origin deploy"; exit 1; }
git fetch -q origin deploy dev
echo "deploy vs origin/deploy (ahead behind): $(git rev-list --left-right --count HEAD...origin/deploy)"
if [ -n "${BACKPORT_SHA:-}" ]; then
  [ "$(git rev-parse origin/dev)" = "$BACKPORT_SHA" ] && echo "origin/dev is the back-port: yes" || echo "origin/dev is the back-port: NO"
fi
git log -1 --format='deploy now %h %s'
```

```bash
# block: impact
set -uo pipefail
STATE="$(git rev-parse --absolute-git-dir)/sync-deploy-vps.env"; source "$STATE"
echo "since $(git rev-parse --short "$START"):"
[ -n "$(git diff --name-only "$START" HEAD -- app)" ] && echo "REBUILD WEB_SERVER: app/ changed ($(git diff --name-only "$START" HEAD -- app | wc -l) files)"
[ -n "$(git diff --name-only "$START" HEAD -- nginx .env)" ] && echo "RECREATE NGINX: $(git diff --name-only "$START" HEAD -- nginx .env | tr '\n' ' ')(templates render only at container start)"
[ -n "$(git diff --name-only "$START" HEAD -- docker-compose.yaml)" ] && echo "COMPOSE CHANGED: docker-compose.yaml"
echo "(no line above = nothing to restart)"
```

```bash
# block: e2e
set -uo pipefail
DOMAIN="$(grep -E '^DOMAIN=' .env | cut -d= -f2)"
docker compose ps
echo "https: $(curl -s -o /dev/null -w '%{http_code}' "https://$DOMAIN/")   (expect 200)"
echo "http:  $(curl -s -o /dev/null -w '%{http_code}' "http://$DOMAIN/")    (expect 301)"
```

```bash
# block: cleanup
set -uo pipefail
GITDIR="$(git rev-parse --absolute-git-dir)"; STATE="$GITDIR/sync-deploy-vps.env"
[ -f "$STATE" ] && source "$STATE"
{ printf '%s\n' "${WT_DEV:-}" "${WT_DEPLOY:-}"; git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -E '/sync-(dev|deploy)\.[A-Za-z0-9]+$'; } \
  | sed '/^$/d' | sort -u | while IFS= read -r w; do
    if git worktree list --porcelain | grep -qxF "worktree $w"; then git worktree remove --force "$w" && echo "removed worktree $w"; fi
    rmdir "$w" 2>/dev/null || true
  done
git worktree prune
rm -f "$STATE" "$GITDIR/sync-deploy-vps.gitignore-extra"
git worktree list
```

Arguments (hotfix subject, if typed inline; may be empty):

$ARGUMENTS
