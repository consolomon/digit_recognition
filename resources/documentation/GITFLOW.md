# Gitflow — Digit Recognition

The canonical, self-contained day-to-day gitflow tutorial for this repo,
once `GITFLOW_INIT.md` has been run. Everything needed to actually do
gitflow here lives in this one file — you should not need to cross-reference
anything else to use it correctly.

**Rules live in `CLAUDE.md`, this file shows them applied.** `CLAUDE.md`
keeps supreme policy authority — commit versioning semantics, the
no-Claude-authorship rule and permission scoping are *defined* there. This
file never redefines them; it shows the actual commands that satisfy them,
and links back to `CLAUDE.md` for the "why." If the two ever disagree,
`CLAUDE.md` wins and this file is out of sync — fix this file, per
"Document maintenance" at the end.

Adapted on 2026-10-17 from TechProSvet's `GITFLOW.md`. That project's
incident write-ups were not carried over (they are not this project's
incidents); their lessons are kept in "Inherited hazards" below and in the
comments of `scripts/merge_to_deploy.sh`.

---

## Feature cycle — one backlog item, one feature branch (global rule)

Policy source: `CLAUDE.md` §"Development cycle". Every item from
`BACKLOG.md` runs this sequence; the commands for each step are in
"Day-to-day workflow" below.

| # | Step | How |
|---|---|---|
| 1 | Start the feature | `/new-feature <name>` — Claude **suggests** a name from the backlog item (e.g. `stage3-error-json`) and the owner submits it or types a custom one; the first commit moves the item to *In progress* in `BACKLOG.md` |
| 2 | Build | commits on `feature/<name>`: first one `next_version.sh feature` (F+1, P=0), later ones `patch` |
| 3 | Unit tests | `venv/bin/python -m unittest discover -s tests -t .` |
| 4 | Owner's manual test | `scripts/dr_rebuild.sh` (http://127.0.0.1:8008/) → hand over → wait for approval |
| 5 | Finish the feature | `/finish-feature` — merge into `dev`, push `dev`, delete the branch locally and on the remote |
| 6 | Full tests | on the merged `dev`: the unit suite in the venv **and** in the rebuilt image (`scripts/dr_rebuild.sh` runs it before swapping the container) — nothing skipped |
| 7 | Promote to master | `/promote-master` |
| 8 | Promote to deploy | `/promote-deploy` — merges and pushes `deploy`. **Not a production deploy**: the release on the VPS is an explicit owner action outside the cycle (`DEPLOY_INIT.md` §"Release") |
| 9 | Close | move the item to *Done* in `BACKLOG.md` with the shipped version; ready for the next item at step 1 |

A failed step stops the cycle: fix on the feature branch (before step 5) or
on `dev` (after it) and re-run from that step's test gate.

### Local stack: rebuild script

The local stack (`docker-compose.yaml` on master/dev) is one service,
`web_server`, image and container `dr_web_server`, host port
`${WEB_HOST_PORT:-8008}:8008` (`WEB_HOST_PORT` from the committed `.env`).

```bash
scripts/dr_rebuild.sh                    # [--no-cache]
WEB_HOST_PORT=8009 scripts/dr_rebuild.sh # only if 8008 is ever taken
```

Steps: build the new image (the old container keeps running) → import
check + the smoke tests in throw-away containers of the new image
(`tests/` mounted, `DR_APP_DIR=/app`) → recreate the container → wait for
`/` to answer inside the container → **end-to-end `curl` from the host**
→ print the last 10 log lines and the URL → remove the replaced image. A
failing step before the recreate stops the script with the running
container untouched.

The end-to-end check (since 1.2.2, B-13) follows the compose file of the
checked-out branch: with the dev compose (`master`/`dev`)
`http://127.0.0.1:<WEB_HOST_PORT>/` must answer 200; with the prod compose
(`deploy`, recognised by its `nginx` service) `https://$DOMAIN/` must
answer 200 and `http://$DOMAIN/` 301, `DOMAIN` from `.env` — the request a
user makes, through nginx. So on the VPS a release can be
`git pull --ff-only origin deploy && scripts/dr_rebuild.sh` once the stack
has been started the first time (`DEPLOY_INIT.md` §"Release").

**Keep the feature branch checked out from step 1 to step 5** (`CLAUDE.md`
§"Development cycle"): the owner reviews the changes in the IDE as they
land, so the project directory never switches to another branch mid-feature.
Other branches are read without checking them out:

```bash
git show dev:path/to/file          # a file as it is on dev
git diff dev...HEAD                # everything this feature changes
git log --oneline deploy -5        # recent deploy history
```

If another branch must be checked out (an urgent fix on `dev`), use a
temporary worktree outside the project directory and remove it afterwards:

```bash
git worktree add "$CLAUDE_JOB_DIR/tmp/wt-dev" dev
# … commit there …
git worktree remove "$CLAUDE_JOB_DIR/tmp/wt-dev"
```

**Parallel feature branches — one Claude Code session per branch**
(`CLAUDE.md` §"Development cycle"). With two or more open `feature/*`
branches, each has a dedicated session locked to it; sessions see each other
(`ListAgents`) and coordinate with `SendMessage`. The shared project
directory holds one checkout at a time, so a session's first action after
a new prompt is to get its own branch back:

```bash
git branch --show-current                          # already on feature/<mine>? done
git status --short                                 # another feature's uncommitted work?
git stash push -u -m "wip feature/<other>"         # park it — never carry it across
git checkout feature/<mine>
git stash list | grep "wip feature/<mine>"         # my own parked work, if any
git stash pop stash@{N}                            # N from the line above
```

…then message `feature/<other>`'s session that its work is stashed. The
master session is that feature's session while only one feature branch is
open, and unlocked (any feature branch, announced first) when there are
more. The lock is per feature branch only: `dev`, `deploy` (and `master` via
`/promote-master`) stay shared — the session running `/finish-feature` or a
promotion announces it so they happen one at a time.

---

## Day-to-day workflow

Every command sequence below satisfies `CLAUDE.md` §"Commit message
versioning" (`G.F.P` prefix on every commit) and §"No Claude authorship" (no
`Co-Authored-By`/`Claude-Session` trailer, ever) — that's why every commit
here goes through `scripts/next_version.sh` and an explicit `-m`, rather
than a bare `git commit` or a `git merge --no-ff` that opens an editor.

### Start a new feature

```bash
git checkout dev
git pull origin dev
git checkout -b feature/your-feature-name
```

### First commit on the new branch — bumps F, not P

```bash
NEW=$(scripts/next_version.sh feature)
echo "$NEW" > VERSION
git add VERSION <other changed files>
git commit -m "$NEW <subject>"
```

### Every commit after that on this branch — bumps P

```bash
NEW=$(scripts/next_version.sh patch)
echo "$NEW" > VERSION
git add VERSION <other changed files>
git commit -m "$NEW <subject>"
```

A generation bump (`scripts/next_version.sh generation`) only ever happens
on the project owner's explicit instruction for that specific commit — see
`CLAUDE.md`.

### Manual test gate — before any push or promotion (global rule)

**Every test sequence before a push includes the project owner's manual test
of the project built and running in the local Docker environment.** Only
after the owner's explicit approval does anything leave the machine: no
`git push` to `dev`/`master`/`deploy`, no `/finish-feature` push, no
`/promote-master`, no `/promote-deploy`, no VPS release. In the feature
cycle the manual test is step 4, between the unit tests and
`/finish-feature`; the full tests after the merge gate `/promote-master`.

```bash
venv/bin/python -m unittest discover -s tests -t .      # automated suite first
scripts/dr_rebuild.sh                                   # or: docker compose up -d --build
# -> hand over for the owner's manual test, wait for "approve"
```

Local commits and local merges are fine before approval; the push is what
waits. Policy source: `CLAUDE.md` §"Test sequence".

### Finish feature — merge into dev, delete temp branch

```bash
git checkout dev
git pull origin dev
git merge --no-ff --no-commit feature/your-feature-name
git commit -m "$(cat VERSION) merge: finish feature/your-feature-name"
git push origin dev
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

The merge carries the version forward unchanged (it isn't new work) — the
explicit `-m` is required, since a bare `git merge --no-ff` opens an editor
with a default message that has no version prefix. **Read `VERSION` only
after the merge** (`--no-commit`, then commit): right after `git checkout
dev` the file still holds dev's older value, so a one-line `git merge -m
"$(cat VERSION) …"` stamps the merge with the wrong version.

### Promote dev → master (after any dev update)

```bash
git checkout master
git pull origin master
git merge --no-ff --no-commit dev
git commit -m "$(cat VERSION) merge: sync dev → master"
git push origin master
git checkout dev
```

Same carry-forward rule — `cat VERSION` must run *after* `dev` is merged in.

### Promote dev → deploy (when ready to release a new version)

Run a **copy** of the script (see "Inherited hazards" — the checkout of
`deploy` swaps `scripts/merge_to_deploy.sh` for deploy's older copy
mid-run):

```bash
cp scripts/merge_to_deploy.sh /tmp/merge_to_deploy.sh   # Claude: "$CLAUDE_JOB_DIR/tmp/"
bash /tmp/merge_to_deploy.sh
git checkout dev
```

The script carries the version forward correctly on its own merge commit —
nothing extra to do here.

### Release on the VPS

Pushing `deploy` builds nothing by itself. Releasing is a manual owner step
on the dedicated VPS: `git pull --ff-only origin deploy && docker compose up
-d --build`, then the end-to-end check through nginx (`DEPLOY_INIT.md`
§"Release"). Until `DEPLOY_INIT.md` is done (the VPS isn't provisioned yet,
`BACKLOG.md` OD-3/OD-4), there is no production at all.

### VPS hotfixes — `/sync-deploy-vps`

Branch management happens on the dev PC, with **one sanctioned exception**:
`/sync-deploy-vps` (`.claude/commands/sync-deploy-vps.md`, adopted from
Sreda-obitaniya on 2026-10-17), run in a Claude Code session **on the VPS**
(`DEPLOY_INIT.md` §"Claude Code on the VPS"). A fix made on the VPS is
otherwise at risk from the next `git pull`, or drifts from `dev` until
someone back-ports it by hand. The command:

1. **Part A** — commits local VPS changes as a hotfix (version = highest
   `VERSION` on either branch + P) and pushes `deploy`; a clean tree just
   fast-forwards onto `origin/deploy`. Never merges, rebases or force-pushes.
2. **Part B** — back-ports `deploy` into `dev` in a temporary worktree:
   dev keeps its own `DEPLOY_OWNED` and `DEV_ONLY` paths and `.gitignore`,
   everything else (app code, `DEPLOY_KEEP` docs, `.env`, `VERSION` = the
   higher value) takes the 3-way merge; every collision is a dialog.
3. **Part C** — promotes the back-port (or `origin/dev`) into `deploy` in a
   second worktree, restores deploy's owned paths **unconditionally**, and
   after one approval pushes `dev` and `deploy` in a single
   `git push --atomic`, then fast-forwards the production checkout.
4. **Part D** — offers only the restarts that apply (`web_server` rebuild,
   nginx recreate, compose up), waits for approval, and ends with the
   end-to-end request through nginx.

Why the promote after a back-port is mandatory and atomic: the back-port
makes deploy an ancestor of `dev` with dev's side restored on the owned
paths; without the matching promote, the next dev-PC promotion would see
*dev* changing `docker-compose.yaml` relative to the new merge base (the
"ancestry flip"). Both merges commit with the version carried forward.

**After a sync moved `dev`, `git pull` it on the dev PC** (and tell open
feature sessions) before new work. `master` is never touched by the
command — promote it from the dev PC as usual.

Verified offline on 2026-10-17 with the command's own blocks against
throwaway repos — 38 checks, all passing: dev-PC promotion keeping both
sides' `DEPLOY_KEEP` edits and the prod compose; a VPS hotfix back-ported
and promoted atomically (dev keeps its compose, `resources/` and
`.gitignore`; `VERSION` equal on both); the next dev-PC promotion after it;
a re-run converging to nothing.

---

## Multi-developer gitflow scripts — `scripts/gitflow/` (B-13)

An **AI-free** gitflow for a *new* learning repository, in which several
developers rebuild this app from an empty directory up to stage 3,
independently, sharing their results through `master`. Plain bash, no
Claude Code, language-agnostic. It does **not** change this repository's own
workflow (the slash commands and rules above). Owner decisions of
2026-10-25 shaped it; they are recorded here.

### The scripts

All paths are relative to the project root; every script `cd`s there first
and prints its own help with `--help`.

| Script | Replaces | What it does |
|---|---|---|
| `scripts/gitflow/gitflow_master_init.sh` | `GITFLOW_INIT.md` Steps 1–4 | Tutor: dialog → new local repo from the starter pack → `master` + `deploy` → `gh repo create`, push, merge-commit-only settings, collaborators, "require PR" on `master` (refused on free private repos — then by convention) |
| `scripts/gitflow/gitflow_init.sh --devname NAME` | — | Every developer (tutor too): dialog (gh login, https/ssh, push access / invitation) → clone → `git config gitflow.devname NAME` → `dev/NAME` from `master` (or resume it) |
| `scripts/gitflow/new_stage.sh --number N --name NAME` | `/new-feature` | `stage-N/<dev>/NAME` from `dev/<dev>`; first commit `G.N.0 start stage N: NAME` |
| `scripts/gitflow/finish_stage.sh` | `/finish-feature` | `TEST_CMD` + manual-test question → merge into `dev/<dev>` (`VERSION` conflict → higher value, other conflict → abort, back on the stage branch) → push, delete the stage branch |
| `scripts/gitflow/promote_master.sh` | `/promote-master` | Opens / updates the PR `dev/<dev>` → `master` (title `<VERSION> merge: dev/<dev> → master`); the tutor merges it in GitHub |
| `scripts/gitflow/promote_deploy.sh` | `/promote-deploy` + `merge_to_deploy.sh` | Anyone: `deploy` becomes `dev/<dev>`'s tree (incoming dev wins), deploy-owned paths kept, `Promoted-From:` trailer; temp worktree |
| `scripts/gitflow/sync_deploy_vps.sh --master \| --dev` | `/sync-deploy-vps` | VPS: hotfix capture → cherry-pick the hotfix commits onto `master` (via `hotfix/<V>` + PR) or onto the last promoter's `dev/<x>`; prints restart reminders |
| `scripts/gitflow/dr_rebuild.sh [--no-cache] [--check-only]` | `scripts/dr_rebuild.sh` | Build → optional `IMAGE_TEST_CMD` in the new image → recreate → `curl` localhost (dev compose) or `https://<server_name>/` (prod compose) |
| `scripts/gitflow/README.md` | — | The developer guide (developers only, not the tutor): join, stage cycle, version bumps, sharing, deploy, taking `master` in by hand, troubleshooting. Shipped into every course repo |
| `scripts/gitflow/lib.sh`, `scripts/gitflow/gitflow.conf` | — | Shared helpers; per-repo settings (`APP_DIR`, `WEB_SERVICE`, `APP_PORT`, `TEST_CMD`, `IMAGE_TEST_CMD`, `REQUIRED_TOOLS`, `DEPLOY_OWNED` / `DEV_ONLY` / `DEPLOY_KEEP`) |
| `scripts/gitflow/starter/` | — | The starter pack (`MANIFEST` = required files; `_deploy/` = deploy overlay). Seeded with this project's `docker-compose.yaml`, `.gitignore`, `VERSION`, `nginx/default.conf`, `app/Dockerfile`, `app/requirements.txt`; stage material (B-14): `app/stage1/model1.py` (recalibrated), `app/stage2/serialization_utils.py` (`jsonify` / `dejsonify`; imports `.neuron`, which the learner writes), `app/stage2/dataset.json` (training + validation). Copies of this project's `app/` files — re-copy after changing them; the owner extends it |

Distribution: the tutor holds `scripts/gitflow/`; `gitflow_master_init.sh`
commits the starter pack **and** the scripts plus `README.md` (minus
itself and the pack) into the new repo, so developers get them with the clone. Only
`gitflow_init.sh` (self-contained) is handed out before that.

### Model

| Topic | Decision (owner, 2026-10-25) |
|---|---|
| Branches | `master`, `deploy` shared; `dev/<dev>` per developer; `stage-<N>/<dev>/<name>` cut from its own `dev/<dev>`. Scripts that switch branches end on `dev/<dev>` |
| Sharing | PR `dev/<dev>` → `master`, merged by the tutor. Developers' versions are independent; `master` is a controlled sharing display — PR conflicts are expected and not resolved by developers (the tutor reviews branches directly) |
| Deploy | Anyone promotes their own `dev/<dev>`; **incoming dev wins** (`merge -s ours` for history + `read-tree` of dev's tree, then `DEPLOY_OWNED` restored, `DEV_ONLY` stripped, `DEPLOY_KEEP` 3-way merged with `git merge-file`). No conflicts by construction; re-promoting an already-merged branch works (plain commit) |
| Versioning | `G.F.P` with **F = stage number**: `new_stage.sh` sets `G.N.0`, later commits bump P by hand; merges carry forward; `VERSION` conflicts take the higher value. New repo starts at `1.0.0`, `deploy` at `1.0.1` |
| VPS back-port | **Cherry-pick, not merge** (decided 2026-10-25 while building): `deploy`'s history contains every developer who promoted, so merging it would drag their commits into `dev/<x>` / `master` (and conflict on `master`). The hotfix commits = `deploy`'s first-parent non-merge commits since its last `Promoted-From:` commit; already-applied ones are skipped. No promote-back / atomic push is needed: `promote_deploy.sh` restores the deploy-owned paths unconditionally, so there is no ancestry flip |
| Part D | No restart prompts — `sync_deploy_vps.sh` prints the commands that apply and `scripts/gitflow/dr_rebuild.sh --check-only` |
| Starter config | Plain `nginx/default.conf` (no envsubst template), no `.env`: `__DOMAIN__`, `__CERTBOT_EMAIL__`, `__WEB_HOST_PORT__`, `__APP_PORT__` baked in by the dialog; no fixed `container_name` (compose prefixes the project) |
| Language | Nothing Python-specific in the scripts: tests via `TEST_CMD` / `IMAGE_TEST_CMD`, tools via `REQUIRED_TOOLS`, required files via `MANIFEST` |
| Optional helpers | none — no `commit.sh` / `sync_master.sh`; version bumps and pulling `master` into a dev branch stay manual |

Hard rules in every script: `set -euo pipefail`; never force-push, rebase
or `reset --hard`; explicit `G.F.P` messages; no AI attribution; every push
asks first; merges into shared branches run in temporary worktrees under
`$TMPDIR` (the developer's checkout never switches mid-run, so the
"script replaced mid-run" hazard of `merge_to_deploy.sh` does not apply).

**Hazard (by design of "incoming dev wins"):** a VPS edit that is not
captured by `sync_deploy_vps.sh` is overwritten by the next promotion.
Capture it in the same sitting.

### Verification (2026-10-25)

Offline harness (bare repos as GitHub, `url.insteadOf`, a stub `gh`, tutor
+ alice + bob + a VPS checkout, a non-Python app): **57 checks, all
passing** — init of `master`/`deploy` with baked placeholders, joins and
resume, stage cycle with the test gate and conflict abort, PR create/update,
three promotions without conflicts, hotfix `--dev` / `--master`, a
back-port collision, re-runs converging. `scripts/gitflow/dr_rebuild.sh`
run against a real local Docker stub stack (nginx-based app): build,
in-image test, 200 check, image cleanup, `--check-only`, prod-compose
failure path. `shellcheck` was not available (download blocked) — only
`bash -n`.

---

## Summary table

| Action | Command |
|---|---|
| Feature cycle | `/new-feature` → build → unit tests → manual test → `/finish-feature` → full tests → `/promote-master` → `/promote-deploy` → close in `BACKLOG.md` |
| Manual test gate (before any push) | automated tests → `scripts/dr_rebuild.sh` → owner's manual test → approval |
| Start new feature | `git checkout dev && git checkout -b feature/name` |
| First commit on it | `NEW=$(scripts/next_version.sh feature); echo "$NEW" > VERSION; git add VERSION ...; git commit -m "$NEW <subject>"` |
| Later commits on it | same, with `scripts/next_version.sh patch` instead of `feature` |
| Finish feature | `git checkout dev && git merge --no-ff --no-commit feature/name && git commit -m "$(cat VERSION) merge: finish feature/name" && git branch -d feature/name` |
| Promote to master | `git checkout master && git merge --no-ff --no-commit dev && git commit -m "$(cat VERSION) merge: sync dev → master" && git push origin master` |
| Promote to deploy | `cp scripts/merge_to_deploy.sh /tmp/ && bash /tmp/merge_to_deploy.sh` |
| Release | on the VPS: `git pull --ff-only origin deploy && scripts/dr_rebuild.sh` (rebuild + end-to-end check) |
| VPS hotfix / sync | on the VPS, in Claude Code: `/sync-deploy-vps [subject]`; then `git pull` dev on the dev PC |

---

## Claude Code automation

Custom slash commands in `.claude/commands` wrap the workflow above:

| Command | File | What it does |
|---|---|---|
| `/new-feature` | `.claude/commands/new-feature.md` | Creates a new `feature/` branch from `dev` (suggests a name, owner submits or overrides it) |
| `/finish-feature` | `.claude/commands/finish-feature.md` | Merges the current feature branch into `dev`, deletes it |
| `/promote-master` | `.claude/commands/promote-master.md` | Merges `dev` into `master` and pushes |
| `/promote-deploy` | `.claude/commands/promote-deploy.md` | Runs a copy of `scripts/merge_to_deploy.sh` |
| `/sync-deploy-vps` | `.claude/commands/sync-deploy-vps.md` | **VPS only:** hotfix capture, back-port into `dev`, promote into `deploy`, atomic push (§"VPS hotfixes") |

`.claude` is committed to all three branches (on `deploy` since 2026-10-17,
so the VPS has `/sync-deploy-vps`). The first four commands belong to the
dev PC; `/sync-deploy-vps` refuses to run anywhere but a `deploy` checkout.
They are project-scoped — they only appear when Claude Code is opened in
this project's directory.

---

## Invoking the workflow — PyCharm / terminal / manual prompts

### Terminal (Claude Code CLI)

```bash
cd "/home/consolomon/PycharmProjects/Digit Recognition"
claude
```

Then type any slash command:

```
/new-feature stage3-error-json
/finish-feature
/promote-master
/promote-deploy
```

### PyCharm

PyCharm's Claude Code plugin exposes the same slash commands directly in its
chat panel — no separate setup needed.

Alternatively, configure PyCharm **External Tools** to run the underlying
git commands without going through Claude Code at all:
`Settings → Tools → External Tools → +`

**Tool: New Feature Branch**
- Program: `bash`
- Arguments: `-c "cd \"$ProjectFileDir$\" && git checkout dev && git pull origin dev && git checkout -b feature/"`
- Working directory: `$ProjectFileDir$`

**Tool: Merge to Deploy**
- Program: `bash`
- Arguments: `-c "cp \"$ProjectFileDir$/scripts/merge_to_deploy.sh\" /tmp/ && cd \"$ProjectFileDir$\" && bash /tmp/merge_to_deploy.sh && git checkout dev"`
- Working directory: `$ProjectFileDir$`

**Tool: Promote to Master**
- Program: `bash`
- Arguments: `-c "cd \"$ProjectFileDir$\" && git checkout master && git merge --no-ff --no-commit dev && git commit -m \"$(cat VERSION) merge: sync dev → master\" && git push origin master && git checkout dev"`
- Working directory: `$ProjectFileDir$`

The project path contains a space, hence the quoted `$ProjectFileDir$`.
Assign keyboard shortcuts via `Settings → Keymap → External Tools`. Unlike
the slash commands, these External Tools bypass Claude Code entirely, so
they don't know about `CLAUDE.md`'s rules on their own — the version-aware
`-m` above is baked into the Arguments field for exactly that reason. If you
add more External Tools this way, bake the same pattern in rather than
relying on a default merge message.

### Manual prompts (without slash commands)

If you'd rather prompt Claude Code directly instead of using the slash
commands, these produce the same result — Claude Code still applies
`CLAUDE.md`'s versioning and no-authorship rules regardless of phrasing:

**New feature:**
```
Start a new feature branch from dev. Branch name: feature/[NAME].
```

**Finish feature:**
```
I'm done with this feature. Merge it into dev, delete the branch locally
and on remote, then push dev to origin.
```

**Promote to master:**
```
Merge dev into master and push both to origin.
```

**Promote to deploy:**
```
Run (a copy of) scripts/merge_to_deploy.sh to merge dev into deploy.
```

---

## `resources/` on deploy — the `DEPLOY_KEEP` exception

`scripts/merge_to_deploy.sh` strips its `DEV_ONLY` paths (the whole
`resources/` tree), then restores only the paths listed in its
`DEPLOY_KEEP` array. Currently:

```
resources/documentation/GITFLOW.md
resources/documentation/GITFLOW_INIT.md
resources/documentation/DEPLOY_INIT.md
```

These are the operational docs someone running the VPS needs in hand.
Everything else in `resources/` (architecture, backlog, sandbox) stays
dev-side. A `DEPLOY_KEEP` path that doesn't exist on `dev` yet is skipped,
not an error; a directory entry is guarded against conflicts on any file
under it.

**Both sides may write them** (since 2026-10-17). The script re-stages
git's **3-way merge result** for every `DEPLOY_KEEP` path, so an edit made on
`dev` and one made on `deploy` (e.g. a VPS record via `/sync-deploy-vps`)
both survive a promotion. The two earlier rules each lost data: "always
deploy's copy" reverted every dev-side doc update (TechProSvet,
2026-09-14), "always dev's copy" silently discarded VPS-side records
(Sreda-obitaniya). A genuine per-line conflict on a `DEPLOY_KEEP` path
aborts the promotion instead of silently picking a side; the script
captures the conflict set *before* touching the index, because a
`git rm`/`git add` would clear the unmerged flag first.

**Also note:** these paths live under `resources/`, which is `.gitignore`d
on `deploy` — the restore loop uses `git add -f`.

---

## Inherited hazards

Lessons from TechProSvet's incidents with the same script (2026-09-13 …
09-29), already handled by `scripts/merge_to_deploy.sh` and these commands —
listed so nobody "simplifies" the fix away:

| Hazard | Handling |
|---|---|
| `set -e` aborts on an *expected* conflict (dev edited the deploy-owned compose; a dev-only path modified/deleted) before the script's own resolution runs | `git merge … \|\| true`, then a fresh `--diff-filter=U` check at the end |
| New dev-only files merge in conflict-free and would leak to `deploy` | `git rm --cached -rf` of every `DEV_ONLY` path runs on whatever is staged, conflicted or not |
| Restoring `DEPLOY_KEEP` from one side loses the other side's edits | re-stage git's 3-way merge result |
| Ancestry flip after a VPS back-port: dev's side of deploy-owned paths looks like dev's change | `DEPLOY_OWNED` restored to deploy's version unconditionally (script and `/sync-deploy-vps`), back-port + promote pushed atomically |
| nginx resolves a literal `proxy_pass` host once and keeps the stale IP after a `web_server` recreate → 502s (Sreda-obitaniya, 2026-09-09, ~22 h) | variable upstream + `resolver 127.0.0.11` in the nginx template |
| `VERSION` conflicts when `deploy` got its own commits | dev's value wins (carry-forward) |
| `.gitignore` conflicts (both branches own it) | union of lines + WARNING to review |
| Nothing to merge → no `MERGE_HEAD` → strip steps would delete every `DEPLOY_KEEP` path | early exit "nothing to promote" |
| `$(cat VERSION)` read before the merge stamps the merge commit with the target branch's old version | `--no-commit`, then commit |
| Running `merge_to_deploy.sh` in place: `git checkout deploy` swaps/removes the file under the running bash | run a copy |

---

## Branch drift — how it happens and how to close it

A merge only carries files that changed on the *source* side. When `deploy`
alone edits a file (a hotfix applied directly on the VPS, say), git keeps
deploy's version at every future promotion and never reports a conflict — the
drift is silent and permanent until someone back-ports it deliberately.
**Never leave a VPS edit on `deploy` alone**: run `/sync-deploy-vps` on the
VPS in the same sitting, which back-ports it to `dev` and promotes it back
atomically.

**Detecting it.** After any promotion, diff the branches excluding the
intentional, by-design differences:

```bash
git diff --name-only deploy dev \
  | grep -v -E "^(resources/|docker-compose\.yaml|\.gitignore)"
```

Anything listed (besides `VERSION` right after a deploy-only commit) is
unintended drift. Note git **quotes** paths containing spaces or non-ASCII,
so a plain `^resources/` pattern can miss a quoted path — check for a
leading quote too.

**Read the direction carefully.** `git diff A B` shows how to turn A into B,
so a `-` line means *A has it, B does not*. Confirm with the file list rather
than the diff sign alone:

```bash
git ls-tree -r --name-only <branch> -- <path>
```

**A `deploy`→`dev` back-port by hand is a trap — use `/sync-deploy-vps`.**
Merging `deploy`'s independent commits back into `dev` changes the
merge-base relationship: paths `deploy` owns by design
(`docker-compose.yaml`'s prod version, the `.gitignore` deploy-only lines)
can flip to look like *dev's* changes relative to the new base. The next
`merge_to_deploy.sh` run would then have no conflict to report and would
silently push `dev`'s versions of those paths — which is wrong. Before
committing any such back-port, verify:

```bash
git diff --cached --name-status origin/deploy -- docker-compose.yaml
```

prints nothing unexpected. `/sync-deploy-vps` does all of this for you —
the mandatory promote restores deploy's side and both refs move in one
atomic push; never push a hand-made back-port on its own.

---

## Git configuration recommendations

```bash
git config --global push.default current
git config --global merge.ff false
```

(Not applied — `--global` affects every repo; owner's call.)

---

## Record: Claude-authorship history check (2026-10-17)

Enforcement: the tracked `.claude/settings.json` (all branches, so the VPS
too) turns attribution off — `"attribution": {"commit": "", "pr": "",
"sessionUrl": false}` plus `"includeCoAuthoredBy": false` for older Claude
Code versions; same config as Sreda-obitaniya. Added in `1.0.4`.


Per `CLAUDE.md` §"No Claude authorship in repo operations" (retroactive).
History at adoption: one commit, `eaa0903 v1.0.0 c1.0.0: Init commit`,
author `consolomon`, no `Co-Authored-By` / `Claude-Session` trailer; no
GitHub PRs. **Nothing to rewrite.** Should a trailer ever slip in, the
rewrite is a one-time, high-blast-radius operation (every later hash
changes, force-push of all three branches) — take backup tags first and
agree it with the owner each time; TechProSvet did it once with `git
filter-branch --msg-filter` (2026-09-13).

---

## Document maintenance

This file is the canonical gitflow tutorial (see the intro) — that status
means it gets updated **automatically, as part of making the change**, not
as a separate follow-up task, whenever any of the following happens:

- a `CLAUDE.md` rule that affects git operations changes (versioning
  semantics, authorship policy, permission scoping) — reflect it in the
  relevant command examples here;
- `scripts/merge_to_deploy.sh` (its `DEPLOY_OWNED` / `DEV_ONLY` /
  `DEPLOY_KEEP` arrays are also read by `/sync-deploy-vps`),
  any `scripts/gitflow/*.sh` script or `scripts/gitflow/starter/` (the
  "Multi-developer gitflow scripts" section must match them),
  `.claude/commands/sync-deploy-vps.md`, `scripts/next_version.sh`,
  `scripts/dr_rebuild.sh`, or any `.claude/commands/*.md` gitflow script
  changes — this file's command examples must match what they actually do;
- the repo layout changes (a new top-level directory, a new dev-only tool,
  a new `DEPLOY_KEEP` entry) — update the branch inventory in
  `GITFLOW_INIT.md` and the `DEPLOY_KEEP` list and drift-detection
  exclusion pattern here;
- a real gitflow incident happens on this project (not a hypothetical one
  — don't invent incident write-ups to pad this file).

This file and `GITFLOW_INIT.md` are themselves plan docs under `CLAUDE.md`
§"Keep the plan docs in sync".
