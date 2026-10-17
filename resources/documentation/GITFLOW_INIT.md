# Gitflow Init — Digit Recognition

One-time bootstrap of the three-branch gitflow model for this repo.
Adapted on 2026-10-17 from TechProSvet's `GITFLOW_INIT.md` (itself adapted
from an older template); the adaptation decisions are recorded at the end
("Adaptation record").

For ongoing day-to-day workflow once this is done, see `GITFLOW.md`.

---

## Three permanent branches

- **master** — superset of all files. Used locally on the dev machine.
- **dev** — project source + dev tools (`.claude` commands, `scripts/`) +
  the full `resources/` design record. Day-to-day development branch.
- **deploy** — project source + `.claude/` + `scripts/` (the VPS runs
  Claude Code and `/sync-deploy-vps`, owner 2026-10-17) + the production
  `docker-compose.yaml` (web server + nginx + certbot); `resources/` only as
  the `DEPLOY_KEEP` docs. Checked out on the dedicated VPS
  (`DEPLOY_INIT.md`).

Temporary feature branches are created from `dev`, merged back into `dev`,
then deleted.

---

## Branch file inventory

| File / Directory | master | dev | deploy |
|---|---|---|---|
| `app/` (Flask app, incl. EMNIST dataset + weights) | ✓ | ✓ | ✓ |
| `docker-compose.yaml` | ✓ (dev ver.) | ✓ (dev ver.) | ✓ (prod ver.) |
| `nginx/templates/` (nginx config template) | ✓ | ✓ | ✓ |
| `nginx/certbot/` (certificates, ACME webroot) | ✗ | ✗ | ✗ (created on the VPS, git-ignored everywhere) |
| `.env` (committed — no secrets, owner 2026-10-17), `CLAUDE.md`, `VERSION` | ✓ | ✓ | ✓ |
| `tests/` | ✓ | ✓ | ✓ (harmless there — outside the `./app` build context) |
| `scripts/` | ✓ | ✓ | ✓ (since 2026-10-17 — `/sync-deploy-vps` reads `merge_to_deploy.sh`) |
| `.claude/` (`commands/`, `settings.json`) | ✓ | ✓ | ✓ (since 2026-10-17 — the VPS runs `/sync-deploy-vps`; `settings.json` keeps attribution off there too) |
| `resources/` (incl. `documentation/`) | ✓ (full) | ✓ (full) | `DEPLOY_KEEP` paths only — see `GITFLOW.md` §DEPLOY_KEEP |
| `.idea`, `venv`, `.mcp.json`, `__pycache__` | ✗ | ✗ | ✗ |

`nginx/` is tracked on `dev` although only the production stack uses it,
so its edits go through the normal feature cycle instead of being made on
`deploy` by hand.

---

## Step 0 — Prerequisites

```bash
gh --version
gh auth status
```

Status: **done** — `gh` logged in as `consolomon`.

---

## Step 1 — Initialize local repository on master

Status: **done** (2026-10-17). The repo already existed (`eaa0903 v1.0.0
c1.0.0: Init commit`, older message format, not rewritten) with remote
`origin` = `github.com/consolomon/digit_recognition`. `.gitignore` is the
master/dev version:

```
.mcp.json
.idea/
venv/
__pycache__/
*.pyc
*.pyo
.DS_Store
nginx/certbot/
```

`.claude/settings.local.json` is ignored by the owner's global git ignore
(`~/.config/git/ignore`), so it never needs a line here. `.env` is **not**
ignored: it is committed on every branch (owner, 2026-10-17 — it replaced
`.env.example`; no secrets in it, ever).

The workflow upgrade landed before the first push as `1.0.1` (gitflow,
versioning, docs, docker, tests — a P bump, direct commit on `master`;
`VERSION` was seeded with `1.0.0`) and `1.0.2` (web server port
8001 → 8008, `.env` tracked), folded into the bootstrap at the owner's
request rather than run as a feature.

---

## Step 2 — Create dev branch

`dev` starts as a copy of `master`. No file changes needed.

```bash
git checkout -b dev
```

---

## Step 3 — Create deploy branch and configure it

### 3.1 Create branch from dev

```bash
git checkout -b deploy
```

### 3.2 Update `.gitignore` for deploy

Append the deploy-only exclusion to the file already on `dev`:

```
resources/
```

### 3.3 (removed 2026-10-17)

`.claude/` and `scripts/` used to be untracked on deploy here. They now stay
— the VPS runs Claude Code and `/sync-deploy-vps`, which reads its path
lists from `scripts/merge_to_deploy.sh`. The only dev-only path is
`resources/` (the `DEV_ONLY` array in that script).

### 3.4 Strip `resources/` to the `DEPLOY_KEEP` allowlist

```bash
git rm --cached -r resources
git add -f resources/documentation/GITFLOW.md \
           resources/documentation/GITFLOW_INIT.md \
           resources/documentation/DEPLOY_INIT.md
```

— exactly the `DEPLOY_KEEP` array in `scripts/merge_to_deploy.sh`
(`git add -f`: `resources/` is ignored on deploy). The files stay on disk
(ignored) while `deploy` is checked out on the dev PC; `git checkout dev`
puts them back under tracking.

### 3.5 Replace `docker-compose.yaml` with the production version

The dev compose runs only `web_server` with a host port
(`${WEB_HOST_PORT:-8008}:8008`). The production version:

- `web_server` — `build: ./app`, gunicorn on 8008, **no host port** (only
  nginx reaches it, `proxy_pass http://web_server:8008`), `restart: always`;
- `nginx` (`dr_nginx`) — 80/443, renders `nginx/templates/*.template` with
  `DOMAIN` from `.env`, mounts `nginx/certbot/{conf,www}` read-only;
- `certbot` (`dr_certbot`) — webroot `certonly --keep-until-expiring` for
  `${DOMAIN}` / `${CERTBOT_EMAIL}`, runs once per `up` and exits.

The file lives only on `deploy` — it is the `DEPLOY_OWNED` array in
`scripts/merge_to_deploy.sh`, so promotions always keep deploy's version.
Change it on the VPS and capture it with `/sync-deploy-vps` (which keeps
dev's own compose on dev), or by a plain commit on `deploy`.

### 3.6 Commit deploy branch setup

```bash
NEW=$(scripts/next_version.sh patch); echo "$NEW" > VERSION
git add -A
git commit -m "$NEW init deploy branch: DEPLOY_KEEP resources/, prod compose"
```


---

## Step 4 — Push all branches

**Touches the network and shared remote branches — confirm before running
(Scope C).** The remote already exists, so no `gh repo create`.

Status: **done** (2026-10-17, after the owner's manual test of the 8008
stack and explicit approval) — `master` fast-forwarded from `eaa0903`,
`dev` and `deploy` created on `origin`.

```bash
git push -u origin master dev deploy
git checkout dev
```

Verify:
```bash
git branch -a
# * dev
#   deploy
#   master
#   remotes/origin/deploy
#   remotes/origin/dev
#   remotes/origin/master
```

---

## Step 5 — `scripts/merge_to_deploy.sh`

Part of the bootstrap commits on `master`/`dev` and, since 2026-10-17, tracked on `deploy` too; see
`GITFLOW.md` for the script and the rules around it.

---

## Step 6 — Git configuration recommendations

```bash
git config --global push.default current
git config --global merge.ff false
```

Not applied (2026-10-17) — `--global` changes every repo on the machine;
the owner decides separately.

---

## Adaptation record (2026-10-17)

Owner answers that shaped this setup:

| Topic | Decision |
|---|---|
| Deploy target | manual nginx + certbot on a VPS (no Coolify) |
| Development unit | plain features, tracked in `BACKLOG.md` (no ROADMAP / PHASEn) |
| Plan-docs folder | `resources/documentation/` |
| Starting version | `VERSION` = `1.0.0`; first commit `1.0.1` |
| Port (2026-10-17, after review) | web server on **8008** inside the container and on the host (`${WEB_HOST_PORT:-8008}:8008`) — `1.0.2` |
| `.env` (2026-10-17, after review) | committed on every branch, replaces `.env.example`; no secrets |
| Dataset + weights | stay in git; kept out of the image by `app/.dockerignore`; `python:3.12-slim` base |
| Tests | `tests/` smoke suite (unittest + Flask test client) |
| Bugs found while reading | recorded in `BACKLOG.md` only |
| Domain / email | `sandbox.prosvet.io` / `consolomon1998@gmail.com` |
| Names | service `web_server`; containers/images `dr_web_server`, `dr_nginx`, `dr_certbot` |
| Production host (2026-10-17) | **dedicated VPS, no Coolify** — own nginx + certbot, Claude Code installed there |
| VPS sync (2026-10-17) | `/sync-deploy-vps` adopted from Sreda-obitaniya; `.claude/` + `scripts/` ship to deploy; `merge_to_deploy.sh` gets `DEPLOY_OWNED` / `DEV_ONLY` arrays and keeps git's 3-way merge result for `DEPLOY_KEEP` |
| nginx upstream (2026-10-17) | variable `proxy_pass` + `resolver 127.0.0.11` (Sreda gotcha 2) |

Refactorings applied: R-1 plan-docs set, R-2 `CLAUDE.md`, R-3 these two
gitflow docs, R-4 versioning + `.gitignore`, R-5 `merge_to_deploy.sh` +
slash commands, R-6 local Docker stack + `scripts/dr_rebuild.sh`, R-7
production compose + nginx template + `DEPLOY_INIT.md`, R-8 smoke tests,
R-9 branch bootstrap (this file's Steps 1–4).

## Next

Once Steps 0–5 are complete, all further gitflow usage — starting features,
promoting to master/deploy — is documented in `GITFLOW.md`; the VPS side in
`DEPLOY_INIT.md`.
