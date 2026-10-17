---
description: Merge the current feature branch into dev and delete it
---

Finish the current feature branch: merge it into `dev` with `--no-ff`, delete
it locally and on the remote, then push `dev`.

Feature-cycle position (`CLAUDE.md` §"Development cycle"): run this only
after the unit tests pass **and** the owner approved the manual test in
local Docker; the full tests, `/promote-master` and `/promote-deploy`
follow it.

With other feature branches open, `dev` is shared: message their sessions
before merging (one merge into `dev` at a time) and again afterwards, so
they can decide whether to merge the new `dev` into their branch.

1. Confirm the current branch is actually a `feature/*` branch — if not, stop
   and ask.
2. Confirm there are no uncommitted changes (`git status`); if there are,
   ask whether to commit or stash before continuing.
3. Run:

```bash
git checkout dev
git pull origin dev
git merge --no-ff --no-commit feature/<name>
git commit -m "$(cat VERSION) merge: finish feature/<name>"
git push origin dev
git branch -d feature/<name>
git push origin --delete feature/<name>
```

If the merge conflicts, stop and report the conflicting files rather than
resolving them unilaterally — this repo's `CLAUDE.md` requires pausing for
decisions that involve reworking prior steps.

The pushes are shared-branch / remote actions (Scope C) — confirm with the
owner before running them unless autonomous mode was granted for Scope C in
the current prompt.

**Versioning:** per `CLAUDE.md` §"Commit message versioning", this merge
carries the version forward unchanged — no bump, just the explicit `-m`
above so the commit still carries the `G.F.P` prefix (a plain `git merge
--no-ff` without `-m` would open an editor with a default message that
lacks it). Read `VERSION` only after the merge — right after `git checkout
dev` it still holds dev's older value (see `promote-master.md`).
