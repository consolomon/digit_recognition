---
description: Start a new feature branch from dev
---

Start a new feature branch from `dev`. Branch name: `feature/$ARGUMENTS`.
If `$ARGUMENTS` is empty, **suggest** a name derived from the
`resources/documentation/BACKLOG.md` item being started (e.g.
`stage3-error-json`) and ask the owner, in an interactive dialog, to submit
it or enter a custom one — never create the branch on an unconfirmed name.
This is step 1 of the feature cycle (`CLAUDE.md` §"Development cycle",
`GITFLOW.md` §"Feature cycle").

The branch's first commit moves its item to *In progress* in
`resources/documentation/BACKLOG.md` (with the branch name). From here
until `/finish-feature`, keep the project directory checked out on this
branch — the owner reviews the changes in the IDE; read other branches with
`git show` / `git diff`, or use a temporary `git worktree` in the job tmp dir.

If another `feature/*` branch is already open (`git branch --list
'feature/*'`), this new branch gets its **own dedicated Claude Code
session**, locked to it (`CLAUDE.md` §"Development cycle" — parallel
feature branches). Tell the owner to open that session and continue there;
notify the other feature sessions (`SendMessage`) that the branch exists.

Run, in order:

```bash
git checkout dev
git pull origin dev
git checkout -b feature/$ARGUMENTS
```

Before running: check `git status` for uncommitted work on the current
branch; if there is any, stash it or ask before switching. Gitflow rules
live in `resources/documentation/GITFLOW.md` (branch model, commands) and
`CLAUDE.md` (versioning, authorship, pause-for-decisions policy).

**Versioning:** per `CLAUDE.md` §"Commit message versioning", the *first*
commit made on this new branch must bump F, not P:

```bash
NEW=$(scripts/next_version.sh feature)
echo "$NEW" > VERSION
git add VERSION <other changed files>
git commit -m "$NEW <subject>"
```

Every commit after that on this branch uses `scripts/next_version.sh patch`
(the default) instead, until the branch is finished.
