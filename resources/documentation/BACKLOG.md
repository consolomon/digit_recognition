# Backlog — Digit Recognition

The project's work list under the feature cycle (`CLAUDE.md` §"Development
cycle"): one item → one `feature/*` branch. Items move *Backlog* →
*In progress* (on the branch's first commit) → *Done* (at the cycle's close,
with the version that shipped it).

---

## Open decisions

Blockers to raise with the owner, never to resolve unilaterally
(`CLAUDE.md` §"Prompt processing").

| ID | Decision | Status |
|---|---|---|
| OD-1 | Production domain | **decided 2026-10-17: `sandbox.prosvet.io`** |
| OD-2 | Certbot registration email | **decided 2026-10-17: `consolomon1998@gmail.com`** |
| OD-3 | VPS host for the nginx + certbot stack | **decided 2026-10-17: a dedicated VPS without Coolify** (not Sreda-obitaniya's or TechProSvet's host — both already hold 80/443), Claude Code installed there for `/sync-deploy-vps`. Machine: the one the Cloudflare record points at (origin IP set in the Cloudflare dashboard). |
| OD-4 | DNS for `sandbox.prosvet.io` | **decided 2026-10-17: A/AAAA record set, proxied by Cloudflare** (resolves to Cloudflare edge IPs `172.67.186.192`, `104.21.36.62`; the origin IP is not visible in DNS). Consequences for the first certificate and SSL mode: `DEPLOY_INIT.md` Step 3. |

## Backlog

Found while reading the code for the workflow upgrade (2026-10-17).

| # | Item | Notes |
|---|---|---|
| B-1 | `/stage3/recognize` error branch returns `jsonify({'message': e})` with an Exception object → `TypeError`, a 500 instead of a JSON error | `app/app.py`; return `str(e)` |
| B-2 | `stage3/learning_engine.py` dataset paths are CWD-relative — training only works when launched from `app/stage3/`; `model3.py` duplicates the constants | anchor to the file's dir, like `WEIGHTS_PATH` |
| B-3 | `stage3/neuron_layer.py` bare `from neuron import Neuron` | works only via the `sys.path` insert; coupled to the pickle guardrail (`ARCHITECTURE.md`) — needs a re-pickle |
| B-4 | Debug `print`s on every request in `stage1/model1.py`, `stage2/model2.py` | use `logging` or drop |
| B-5 | `stage3/model3.py` unused imports (`matplotlib`, `PIL`, `base64`, `io`) | removing them lets `matplotlib` leave `requirements.txt` — a big image-size win |
| B-6 | `stage2/neuron.py` `delta_w = [0.0] * 15` ignores `weights_number` | |
| B-7 | `app/requirements.txt` unpinned | pin at least `numpy>=2` (pickle guardrail) |
| B-8 | `/stage2/learn` overwrites the tracked `stage2/weights.data` inside the container; gunicorn's default 30 s worker timeout vs the page's 120 s | decide where trained weights live; `--timeout` |
| B-9 | Empty `app/static/script.js`; `app/static/MNIST_Dashboard.jsx` is an unused JSX source copy of `history.js` | keep as source or delete |
| B-10 | Page visual redesign | owner request 2026-10-17. Scope (owner, 2026-10-17):<br>1. a design reference dataset from the poster PSD/JPG;<br>2. new background and palette on all 5 pages, keeping the single accent;<br>3. a draft design system ready for new elements;<br>4. a Figma mirror and a Miro "Sandbox" export.<br>Functionality untouched. Result: `DESIGN_SYSTEM.md`, ARCH-4 |
| B-11 | `history.html` loads React, ReactDOM, prop-types and Recharts from unpkg with floating versions (`react@18`, `recharts@2`) | pin exact versions (or vendor them into `static/`), so a CDN release can't break History |
| B-12 | `app/static/MNIST_Dashboard.jsx` (B-9's unused copy) still carries the 1.0 navy colours and the pink milestone | resolve together with B-9: delete it, or regenerate it from `history.js` |

## In progress

| Item | Branch | Started |
|---|---|---|
| B-10 Page visual redesign | `feature/page-visual-redesign` | 2026-10-17 |

## Done

| Item | Version | Date |
|---|---|---|
| Workflow upgrade (gitflow, `G.F.P` versioning, plan docs, slim image, smoke tests) | 1.0.1 | 2026-10-17 |
| Web server port 8001 → 8008; `.env` committed instead of `.env.example` (folded into the bootstrap) | 1.0.2 | 2026-10-17 |
| Production = dedicated VPS; `/sync-deploy-vps` adopted from Sreda-obitaniya; `.claude/` + `scripts/` on deploy; `DEPLOY_KEEP` 3-way merge; nginx variable upstream (folded into the bootstrap) | 1.0.3 | 2026-10-17 |
| Tracked `.claude/settings.json` (attribution off); DNS recorded; first push of `master`/`dev`/`deploy` | 1.0.4 | 2026-10-17 |
