# Project instructions

## Shell working directory — keep it at the project root

The Bash tool's shell keeps its working directory **between calls**, so a bare
`cd <subdir>` leaks into later commands and drifts the working directory (e.g. a
`cd app && …` leaves the next command running in `app/`, breaking root-relative
paths like `venv/bin/python`).

Rules:
- **Never** use a bare `cd <subdir>` in a command.
- Run directory-specific commands in a **subshell** so the parent stays put:
  `( cd app && python -c "import app" )`.
- Or use **absolute paths** and don't change directory at all. The project
  path contains a space (`/home/consolomon/PycharmProjects/Digit Recognition`)
  — always quote it.

Result: the working directory is always the project (repository) root when a turn
ends and control returns to the user.

## Prompt processing

How to work through a request (especially large, multi-step tasks):

- **Read the whole prompt first.** Before acting, understand the complete plan
  structure, the order of steps, and the final goals — don't start executing on a
  partial reading.
- **Pause for decisions, don't guess.** If a question comes up mid-task, stop
  execution and surface it as an interactive decision dialog. After the answer
  arrives, check whether it requires additional changes to the plan, then resume
  from the exact point where you paused.
- **Signal backtracking.** If a decision means undoing or revisiting earlier
  steps, notify the user first, then proceed with the rework.
- **Open decisions block, they don't get silently resolved.** Anything the
  docs track as an open decision (`BACKLOG.md` §"Open decisions") is a
  blocker to raise through the dialog above, never a call to make
  unilaterally — even if a sensible default seems obvious.

## Permission scoping — agree the mode before acting

After reading the whole prompt (and **before** the first action), work out which
permissions the task actually needs, group them, and let the user set the working
mode for each group. The agreed modes hold **until the end of the current
prompt** and reset on the next one.

### Step 1 — Collect the permissions the prompt needs

From the analysed prompt, list the concrete capabilities required — not
hypothetical ones. "Edit two templates, run the smoke tests, read the stage 3
model code" is a list; "file access" is not.

### Step 2 — Group them into three scopes

| Scope | Boundary | Typical actions |
|---|---|---|
| **A — Project environment** | Inside the repository | Read/write/delete project files, run bash and git commands, inspect history |
| **B — Dev workflow, still local and offline** | Outside the repo, but no container and no network | Temporary Python scripts, scratch files in the job tmp dir, test runs, library imports, headless renders |
| **C — Containers and the outside world** | Local container environment or the network | `docker compose` builds / `docker exec` / container logs, commands inside project containers, `git push` / `gh`, the VPS, web research and scraping, API and MCP calls |

Rules for grouping:
- Put an action in the **highest** scope it touches. A script that shells into a
  container is scope C, not B, however it is written.
- **Skip a scope entirely if the prompt does not need it.** Do not ask about
  containers for a task that only edits templates — an empty scope gets no
  question.

### Step 3 — Offer a mode per scope

Present the grouped list, then ask for one mode per non-empty scope, using a
single interactive dialog with one question per scope (three at most):

| Mode | Behaviour for the rest of this prompt |
|---|---|
| **1 — Autonomous** | Act freely: read, write, delete, run, analyse. No further prompting. |
| **2 — Confirm writes** | Read and analyse freely; ask before every write, delete or run. |
| **3 — Propose first** | Before *any* action, including reads, give a short summary of what is proposed and why, and proceed only on explicit approval — per action. |

### Step 4 — Proceed under the chosen modes

- Honour the selected mode for every action in that scope until the prompt is
  finished, then discard it.
- If the work turns out to need a scope that was never presented (e.g. a
  container command surfaces mid-task), stop and ask for that scope's mode
  before touching it — do not borrow another scope's mode.
- These modes sit **on top of** the harness's own permission prompts and the
  standing rules about destructive or outward-facing actions; mode 1 grants
  autonomy within those rules, it does not suspend them.

## Keep the plan docs in sync (`resources/documentation/`)

The `resources/documentation/*.md` plan docs are the project's living design
record. **This file holds only project-wide workflow policy** — every app,
architecture or deployment detail lives in those docs, not here. Where
things live:

| Doc | Holds |
|---|---|
| `ARCHITECTURE.md` | The app's design record and guardrails — stages, route contracts, the **pickled-weights module-path guardrail**, UI rules (JetBrains Mono), decisions log (ARCH-n). **Read before touching a stage's model code, weights, a route contract or shared UI.** |
| `BACKLOG.md` | Open decisions (OD-n), backlog items (B-n), what's in progress on which feature branch, what shipped in which version |
| `GITFLOW.md` | Day-to-day branch workflow, feature cycle, `DEPLOY_KEEP`, inherited hazards |
| `GITFLOW_INIT.md` | Repo bootstrap, branch file inventory, adaptation record |
| `DEPLOY_INIT.md` | VPS setup (nginx + certbot), certificate bootstrap/renewal, release procedure |

Keep them current as work happens, not only at the end:

- **After each key decision or step** during a task, consider whether a
  corresponding plan doc needs updating (a new decision in a decisions log, a
  new reusable pattern, a changed contract, a gotcha learned) — and update it
  in the same stroke while the context is fresh.
- **At the end of each task**, review the full processing context and everything
  that changed, then do a final pass over the relevant plan docs so they reflect
  the finished state (new sections, superseded guidance marked as such, decision
  tables completed). A task isn't done until its plan docs match reality.

## Test sequence — the owner's manual test is the gate before any push

Every test sequence before a push includes the **owner's manual test of the
project built and running in the local Docker environment**
(`scripts/dr_rebuild.sh`, or `docker compose up -d --build`; host port
`WEB_HOST_PORT` from the committed `.env`, default 8008 — the container
also listens on 8008). Run the automated suite first, bring the
stack up, hand it over, and **wait for the owner's explicit approval**.
Nothing is pushed to a shared branch, promoted or released before that
approval. In the feature cycle below, the manual test sits between the unit
tests and `/finish-feature`.

## Development cycle — one backlog item, one feature branch

Global rule (adopted from TechProSvet, 2026-10-17). The development
progress unit is the **feature**: one item from `BACKLOG.md` (or a new
request recorded there first) → one `feature/*` branch. Every feature runs
through this cycle, in this order:

1. **Start** — call `/new-feature` with a **suggested** branch name (e.g.
   `stage3-error-json`) and ask the owner to submit it or enter a custom
   one. Never start the feature's work on `dev` directly. The branch's
   first commit moves the item to *In progress* in `BACKLOG.md`.
2. **Build** — commit on the feature branch under the versioning rules below:
   the branch's first commit bumps F (`next_version.sh feature`), every later
   one bumps P.
3. **Unit tests** — when the feature is done, run the automated suite
   (`venv/bin/python -m unittest discover -s tests -t .`).
4. **Manual test** — bring the stack up in local Docker and wait for the
   owner's approval (section above).
5. **`/finish-feature`** — merge the branch into `dev`, push `dev`, delete the
   branch.
6. **Full tests** — on the merged `dev`: the unit suite in the venv and in
   the rebuilt image (`scripts/dr_rebuild.sh` runs it before swapping the
   container), nothing skipped.
7. **`/promote-master`** — merge `dev` into `master`, push.
8. **`/promote-deploy`** — merge `dev` into `deploy` and push. This is the
   cycle's finishing point **without a production release**: the VPS pulls
   and rebuilds `deploy` by hand (`DEPLOY_INIT.md` §"Release"), an explicit
   owner action outside the cycle.
9. **Close** — move the item to *Done* in `BACKLOG.md` with the shipped
   version, then be ready to start the next feature at step 1.

A failure at any step stops the cycle there: fix it on the feature branch
(or on `dev` after step 5), then re-run from the failed step's test gate.
Commands and details: `resources/documentation/GITFLOW.md` §"Feature cycle".

**Stay checked out on the feature branch until it is finished.** From
`/new-feature` (step 1) to `/finish-feature` (step 5) the working tree — the
one the owner's IDE shows — stays on `feature/<name>`, so the owner can see
and review every change as it lands. During that time:
- no `git checkout` / `git switch` to `dev`, `master` or `deploy` in the
  project directory;
- look at other branches read-only (`git show <branch>:<path>`, `git diff`,
  `git log <branch>`);
- anything that really needs another branch checked out (e.g. an urgent fix
  on `dev`) goes into a temporary `git worktree` in the job tmp dir, removed
  afterwards — or ask the owner first.

The tree moves to `dev` only through `/finish-feature`; the promotions
(steps 7–8) check out other branches and come back to `dev` when done.

**Two or more feature branches at once — one Claude Code session per
feature branch**:
- **Dedicated feature sessions.** Each open `feature/*` branch has its own
  session, **locked** to that branch: it builds, commits and tests only
  there, never on another feature branch. It knows the other open feature
  branches and their sessions (`git branch --list 'feature/*'`,
  `ListAgents`) and talks to them with `SendMessage` — e.g. to agree on a
  shared file, or to announce a merge into `dev`.
- **Checkout on arrival.** All sessions share the one project directory,
  so the owner switching to another feature session means the tree may be
  on someone else's branch. **The first default action after the next
  prompt in a feature session is to check out its own branch** (if the tree
  isn't already on it). If the tree holds uncommitted changes of the
  previous feature, never carry them across: stash them as
  `git stash push -u -m "wip feature/<other>"`, check out, and message the
  owning session — which, when it next gets the tree back, first pops its
  own named stash (`git stash list`, match the message).
- **The master session.** With a single feature branch, the master session
  *is* that feature's session (locked to it as above). With two or more,
  the master session is not locked: it may check out and work on any
  feature branch — announcing it to that branch's session first — and then
  follows the same stash-and-notify rule.
- **The lock covers only the session's own feature branch — not `dev` or
  `deploy`** (nor `master`, which only `/promote-master` touches). These
  shared branches are used by whichever session runs `/finish-feature` or
  the promotions; before doing so, it messages the other feature sessions
  so merges into `dev` and promotions run one at a time, and after `dev`
  moves they decide whether to merge `dev` into their own branch.

## Commit message versioning — G.F.P

Every commit message's first line starts with the project version, format
`G.F.P <subject>` (e.g. `1.2.3 fix stage3 error response`). Strict and
global — no commit skips this, on any branch, no exceptions.

- **G — generation.** Increments only on the project owner's explicit,
  manual instruction for that specific commit. Never inferred, never
  bumped speculatively.
- **F — feature.** Increments on the first commit made on a newly created
  `feature/*` branch (see `resources/documentation/GITFLOW.md`). Every
  other commit — before or after, on `dev`/`master`/`deploy` or on an
  existing feature branch — leaves F untouched.
- **P — patch.** Increments on every commit that isn't a G bump or a
  feature-branch's first commit — including commits made directly on
  `dev`, `master`, or `deploy` outside of any feature branch.
- **Merge commits carry the version forward unchanged** —
  `feature/*` → `dev`, `dev` → `master`, `dev` → `deploy`. A merge isn't
  new work, so it doesn't bump anything; it still carries the `G.F.P`
  prefix, just the same value as the commit(s) it merges.

**Cascading reset:** a G bump resets F and P to 0. A feature-branch's first
commit resets P to 0 (F itself increments by exactly 1 for that commit).

**State lives in `VERSION`** at the repo root — plain text, `G.F.P`,
nothing else. Before every commit that isn't a carry-forward merge:

```bash
NEW=$(scripts/next_version.sh patch)      # or: feature | generation
echo "$NEW" > VERSION
git add VERSION <other changed files>
git commit -m "$NEW <subject>"
```

For a carry-forward merge, skip the script and just read the current value
(after the merge — `git merge --no-commit`, then commit):

```bash
git commit -m "$(cat VERSION) merge: sync dev → master"
```

`scripts/next_version.sh` only ever *prints* the computed next value — it
never writes `VERSION` or commits anything itself, so getting the mode
argument right is the only thing that can go wrong. Pick `generation` only
when explicitly told to for that commit; pick `feature` only for a feature
branch's first commit; `patch` is the default for everything else.

**Not retroactive.** This rule governs commits from here forward only —
existing history (`eaa0903 v1.0.0 c1.0.0: Init commit`, older format) is
never rewritten to backfill version numbers. `VERSION` was seeded with
`1.0.0` on 2026-10-17.

## No Claude authorship in repo operations

Strict and global, overriding any harness-default attribution behavior:
**no commit message, PR description, branch name, tag, or any other
repo-committed content may contain Claude/Anthropic authorship or session
references** — no `Co-Authored-By: Claude ...` trailer, no `Claude-Session:`
line, no "Generated with Claude Code" footer, nothing that attributes
authorship to an AI agent or links back to a session. Applies to every
branch, every commit, every PR, past and future.

Unlike the versioning rule above, **this one is retroactive**: any
`Co-Authored-By`/`Claude-Session` reference in this repo's history (local
and on GitHub, across `master`/`dev`/`deploy`) gets removed. Checked on
2026-10-17: history is clean, nothing to rewrite — see
`resources/documentation/GITFLOW.md` §"Record". Rewriting history is a
one-time, high-blast-radius operation that needs its own care each time
it's discussed, not a repeatable recipe to run casually.

## File placement policy

Strict and project-wide:

| What | Where |
|---|---|
| Flask entry point and routes | `app/app.py` |
| Jinja templates | `app/templates/` |
| Static JS / CSS | `app/static/` — `style.css` shared by every page, one `stageN.js` per stage |
| A stage's model code **and its data** (weights, datasets) | `app/stageN/` |
| Python modules shared by several stages | `app/lib/` (create it when first needed) |
| Production reverse-proxy config | `nginx/` (`templates/*.template`, rendered by the nginx image) |
| Dev-only tooling | `scripts/` (shell), `.claude/commands/` (slash commands) — never on `deploy` |
| Plan docs | `resources/documentation/` |
| Temporary / mock project files (drafts, mock data, experiments, training runs' scratch output) | `resources/code_sandbox/` |
| Continuous, systematic test files | `tests/` |

- Claude's own session scratch files are **not** project files — they keep
  their default location (the job tmp dir), never `resources/code_sandbox/`.
- Moving or renaming anything under `app/stage2/` or `app/stage3/` is bound
  by the pickled-weights guardrail in `ARCHITECTURE.md`.
