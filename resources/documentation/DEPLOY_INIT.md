# Deploy init — Digit Recognition (VPS, nginx + certbot)

One-time setup of the production host, then the release procedure.
Production runs the **`deploy` branch** with its own `docker-compose.yaml`:
`dr_web_server` (gunicorn, no host port) behind `dr_nginx` (80/443, TLS),
certificates from Let's Encrypt via `dr_certbot` (webroot). Branch model:
`GITFLOW_INIT.md`; day-to-day flow: `GITFLOW.md`.

| Setting | Value | Source |
|---|---|---|
| Domain | `sandbox.prosvet.io` | `BACKLOG.md` OD-1 |
| Certbot email | `consolomon1998@gmail.com` | OD-2 |
| VPS host | **open** — see OD-3 (port 80/443 clash if it's the Coolify VPS) | OD-3 |
| DNS | **open** — A record → VPS, Cloudflare notes in OD-4 | OD-4 |

Nothing below has been run yet. **Every step touches a remote host or the
network — confirm before running** (Scope C).

---

## Step 0 — Prerequisites on the VPS

- Docker Engine + the compose plugin, git.
- Ports 80 and 443 free (`ss -ltnp | grep -E ':(80|443)\b'`).
- `sandbox.prosvet.io` resolves to the VPS (`dig +short sandbox.prosvet.io`).
- Read access to `github.com/consolomon/digit_recognition` (deploy key or
  token).

## Step 1 — Clone the deploy branch

```bash
git clone -b deploy git@github.com:consolomon/digit_recognition.git digit_recognition
cd digit_recognition
```

## Step 2 — `.env`

Nothing to create: `.env` is **committed** on every branch (owner,
2026-10-17) and arrives with the clone — `DOMAIN=sandbox.prosvet.io`,
`CERTBOT_EMAIL=consolomon1998@gmail.com`. Check it:

```bash
grep -E '^(DOMAIN|CERTBOT_EMAIL)=' .env
```

Don't edit it on the VPS (a dirty tracked file breaks `git pull` and
drifts from `dev`) — change it on `dev` and release. It holds no secrets;
a future secret goes into an untracked file on the VPS, never into `.env`.
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

The renewal config certbot writes says `standalone`. No need to change it
by hand: the renewal command in Step 5 passes `--webroot -w …`, which
overrides the saved authenticator (and certbot stores the new one), so
renewals work while nginx holds port 80.

## Step 4 — Start the stack

```bash
docker compose up -d --build
docker compose ps
curl -I https://sandbox.prosvet.io/
```

`dr_certbot` runs once on every `up` and exits; with
`--keep-until-expiring` that is a no-op until renewal is due.

## Step 5 — Renewal

Let's Encrypt certificates last 90 days. Cron on the VPS (daily):

```cron
17 3 * * * cd /path/to/digit_recognition && docker compose run --rm certbot renew --webroot -w /var/www/html/ --quiet && docker compose exec nginx nginx -s reload
```

---

## Release — every new version

After `/promote-deploy` pushed `deploy` (an explicit owner action, not part
of the feature cycle until this file is done):

```bash
cd /path/to/digit_recognition
git pull origin deploy
docker compose up -d --build
docker compose ps
curl -fsS https://sandbox.prosvet.io/ >/dev/null && echo up
```

Never edit files on the VPS checkout — `deploy` is written only by
`scripts/merge_to_deploy.sh` (and its own `docker-compose.yaml` /
`.gitignore`). A VPS hotfix is back-ported to `dev` in the same sitting
(`GITFLOW.md` §"Branch drift").

## Status

| Step | Status |
|---|---|
| 0–5 | not started — blocked on OD-3 (VPS host) and OD-4 (DNS) |
