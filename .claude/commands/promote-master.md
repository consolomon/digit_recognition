---
description: Merge dev into master and push
---

Promote `dev` to `master`: merge with `--no-ff` and push.

```bash
git checkout master
git pull origin master
git merge --no-ff --no-commit dev
git commit -m "$(cat VERSION) merge: sync dev → master"
git push origin master
git checkout dev
```

**Versioning:** per `CLAUDE.md` §"Commit message versioning", this merge
carries the version forward unchanged — the explicit `-m` above is required
so the commit still carries the `G.F.P` prefix. Read `VERSION` only **after**
the merge (hence `--no-commit`): right after `git checkout master` the file
still holds master's older value, and a one-line `git merge -m "$(cat
VERSION) …"` stamps the merge with it (happened once on TechProSvet,
2026-09-29).

This is a shared-branch push (Scope C per this repo's permission-scoping
convention) — confirm with the owner before the final `git push origin
master` unless autonomous mode was granted for Scope C in the current
prompt.
