---
description: Run scripts/merge_to_deploy.sh to merge dev into deploy
---

Promote `dev` to `deploy` by running the helper script, which strips
dev-only tooling and applies the `DEPLOY_KEEP` allowlist for `resources/`
(see `resources/documentation/GITFLOW.md` for what it does and why). If
`deploy` already contains `dev`, it stops with "nothing to promote".

Run a copy, not the file in place: the script's own `git checkout deploy`
replaces `scripts/merge_to_deploy.sh` on disk mid-execution with deploy's
(possibly older) copy, and bash reads scripts incrementally — so the
in-place file can change under the running shell:

```bash
cp scripts/merge_to_deploy.sh "$CLAUDE_JOB_DIR/tmp/merge_to_deploy.sh"
bash "$CLAUDE_JOB_DIR/tmp/merge_to_deploy.sh"
git checkout dev
```

**This is not a production deploy.** The push only updates the `deploy`
branch on GitHub; the VPS pulls and rebuilds it by hand
(`resources/documentation/DEPLOY_INIT.md` §"Release"), and that step is an
explicit owner action outside the cycle. Do not run anything on the VPS as
part of this command. Hotfixes made on the VPS come back through
`/sync-deploy-vps` (run there), not through this command.

This pushes to a shared branch (Scope C) — confirm with the owner before
running unless autonomous mode was granted for Scope C in the current
prompt.

**Versioning:** `scripts/merge_to_deploy.sh` already carries the version
forward unchanged for its merge commit (`CLAUDE.md` §"Commit message
versioning") — nothing extra to do here.
