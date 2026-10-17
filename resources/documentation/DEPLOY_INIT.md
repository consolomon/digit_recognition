# Deploy init — Digit Recognition (dedicated VPS, nginx + certbot)

One-time setup of the production host, then the release and hotfix
procedures. Production is a **dedicated VPS without Coolify** (owner,
2026-10-17) running the **`deploy` branch** with its own
`docker-compose.yaml`: `dr_web_server` (gunicorn on 8008, no host port)
behind `dr_nginx` (80/443, TLS), certificates from Let's Encrypt via
`dr_certbot` (webroot). Claude Code runs on the VPS too, for
`/sync-deploy-vps`. Branch model: `GITFLOW_INIT.md`; day-to-day flow:
`GITFLOW.md`. Setup adapted from Sreda-obitaniya's `GITFLOW_DEPLOY.md`.

| Setting | Value | Source |
|---|---|---|
| Domain | `sandbox.prosvet.io` | `BACKLOG.md` OD-1 |
| Certbot email | `consolomon1998@gmail.com` | OD-2 |
| VPS | dedicated, no Coolify — **machine not provisioned yet** | OD-3 |
| DNS | **open** — A record → the VPS's IP, Cloudflare notes in OD-4 | OD-4 |

Nothing below has been run yet. **Every step touches a remote host or the
network — confirm before running** (Scope C).

---

## Step 0 — Prerequisites on the VPS

| Tool | Min version | Purpose |
|---|---|---|
| git | 2.x | pull/push `deploy` (push: `/sync-deploy-vps`) |
| docker + compose plugin | 24.x / v2 | run the stack |
| Node.js | 18+ | required by the Claude Code CLI |
| Claude Code CLI | latest | `/sync-deploy-vps` (Step 6) |

- Ports 80 and 443 free (`ss -ltnp | grep -E ':(80|443)\b'`) — nothing else
  may run a web server on this machine.
- `sandbox.prosvet.io` resolves to the VPS (`dig +short sandbox.prosvet.io`).
- **Push** access to `github.com/consolomon/digit_recognition` over SSH —
  `/sync-deploy-vps` pushes `deploy` and `dev`, so a read-only deploy key is
  not enough. Generate a key on the VPS (`ssh-keygen -t ed25519`), add the
  public key to the GitHub account (Settings → SSH and GPG keys), check with
  `ssh -T git@github.com` ("Hi consolomon!"). Set the commit identity:
  `git config --global user.name consolomon` and `user.email`.

## Step 1 — Clone the deploy branch

```bash
git clone -b deploy git@github.com:consolomon/digit_recognition.git digit_recognition
cd digit_recognition
git branch --show-current     # deploy — the VPS never checks out another branch
```

## Step 2 — `.env`

Nothing to create: `.env` is **committed** on every branch (owner,
2026-10-17) and arrives with the clone — `DOMAIN=sandbox.prosvet.io`,
`CERTBOT_EMAIL=consolomon1998@gmail.com`. Check it:

```bash
grep -E '^(DOMAIN|CERTBOT_EMAIL)=' .env
```

It holds no secrets — a future secret goes into an untracked file on the
VPS, never into `.env`. Change it on `dev` and release, or edit it on the
VPS and capture the edit with `/sync-deploy-vps` (Step 6) — never leave a
VPS edit uncommitted (it breaks the next `git pull`) or on `deploy` alone.
`WEB_HOST_PORT` is unused in production — the deploy compose publishes no
web port (nginx reaches `web_server:8008` on the compose network).

## Step 3 — First certificate (bootstrap)

nginx can't start with the 443 `server` block until the certificate files
exist, so the very first certificate is issued with certbot's **standalone**
server on port 80, before nginx ever runs:

```bash
mkdir -p nginx/certbot/conf nginx/certbot/www
docker compose run --rm -p 80:80 --entrypoint certbot certbot \
  certonly --standalone --non-interactive --agree-tos --no-eff-email \
  --email "$(grep ^CERTBOT_EMAIL= .env | cut -d= -f2)" \
  -d "$(grep ^DOMAIN= .env | cut -d= -f2)"
ls nginx/certbot/conf/live/      # -> sandbox.prosvet.io/
```

`nginx/certbot/` holds the **private keys** — git-ignored on every branch,
never committed. The renewal config certbot writes says `standalone`. No
need to change it by hand: the renewal command in Step 5 passes
`--webroot -w …`, which overrides the saved authenticator (and certbot
stores the new one), so renewals work while nginx holds port 80.

## Step 4 — Start the stack

```bash
docker compose up -d --build
docker compose ps
```

Then the check that actually matters — end to end, through nginx
(`docker compose ps` alone proves nothing):

```bash
curl -s -o /dev/null -w "https: %{http_code}\n" https://sandbox.prosvet.io/   # expect 200
curl -s -o /dev/null -w "http:  %{http_code}\n" http://sandbox.prosvet.io/    # expect 301
```

`dr_certbot` runs once on every `up` and exits; with
`--keep-until-expiring` that is a no-op until renewal is due.

**nginx upstream.** The template proxies to a *variable*
(`set $web_server_host web_server; proxy_pass http://$web_server_host:8008;`
with `resolver 127.0.0.11`), so nginx re-resolves `web_server` through
Docker's DNS on each request. A literal `proxy_pass http://web_server:8008`
is resolved once at nginx start; after any `dr_web_server` recreate (every
release) its IP can change and nginx keeps proxying to the old one → 502s
(Sreda-obitaniya, 2026-09-09, ~22 h down). Never collapse it back. nginx
renders `nginx/templates/*.template` only at container start — after a
change there (or to `DOMAIN` in `.env`), `docker compose up -d
--force-recreate nginx`.

## Step 5 — Renewal

Let's Encrypt certificates last 90 days. Cron on the VPS (daily):

```cron
17 3 * * * cd /path/to/digit_recognition && docker compose run --rm certbot renew --webroot -w /var/www/html/ --quiet && docker compose exec nginx nginx -s reload
```

## Step 6 — Claude Code on the VPS

```bash
# Node.js 18+ (e.g. NodeSource or the distro package), then:
npm install -g @anthropic-ai/claude-code
claude --version
claude            # first run: log in, then /exit
```

Use it from the dev PC through **VS Code Remote SSH** (or a plain SSH
terminal): open the `digit_recognition` folder on the VPS, run `claude`
there. It starts in the project root with `deploy` checked out and finds
`CLAUDE.md` and `.claude/commands/` (tracked on `deploy` since 2026-10-17).
On the VPS, use only `/sync-deploy-vps`; the feature/promotion commands
belong to the dev PC.

---

## Release — every new version

After `/promote-deploy` pushed `deploy` (an explicit owner action, not part
of the feature cycle):

```bash
cd /path/to/digit_recognition
git pull --ff-only origin deploy
docker compose up -d --build
docker compose ps
curl -s -o /dev/null -w "https: %{http_code}\n" https://sandbox.prosvet.io/   # expect 200
```

If `nginx/` or `.env` changed in the release, also
`docker compose up -d --force-recreate nginx`.

## Hotfix on the VPS — `/sync-deploy-vps`

A fix made directly on the VPS (e.g. while diagnosing a live error) is
captured in a Claude Code session on the VPS:

```
/sync-deploy-vps fix nginx client_max_body_size
```

(or bare `/sync-deploy-vps` — a clean tree needs no subject). It commits the
hotfix with the next free version, back-ports `deploy` into `dev`, promotes
it back, pushes both in one atomic push, fast-forwards this checkout and
offers the restarts that apply. Never leave a VPS edit uncommitted or on
`deploy` alone. Details: `GITFLOW.md` §"VPS hotfixes"; the procedure itself
is `.claude/commands/sync-deploy-vps.md`. Afterwards, on the dev PC:
`git pull` on `dev`.

## Status

| Step | Status |
|---|---|
| 0–6 | not started — the VPS isn't provisioned yet (OD-3), DNS pending (OD-4) |
