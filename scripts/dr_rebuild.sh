#!/usr/bin/env bash
# Rebuild and recreate the local "web_server" service (docker-compose.yaml).
#
#   scripts/dr_rebuild.sh [--no-cache]          WEB_HOST_PORT=8002 if 8001 is taken
#
#   1. build    the new image dr_web_server:latest (the old container keeps running)
#   2. pre      in throw-away containers of the NEW image: import check, then
#               the smoke tests (tests/ mounted, DR_APP_DIR=/app so they test
#               the code baked into the image); a failing step stops here —
#               the running container is untouched
#   3. up       recreate the container from the new image
#   4. health   wait until / answers 200
#   5. logs     last 10 log lines
#   6. cleanup  remove the replaced image if nothing uses it any more
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVC=web_server
NO_CACHE=()
for arg in "$@"; do
  case "$arg" in
    --no-cache) NO_CACHE=(--no-cache) ;;
    *) sed -n '2,4p' "$0" >&2; exit 2 ;;
  esac
done

compose() { docker compose -f "$REPO/docker-compose.yaml" --project-directory "$REPO" "$@"; }
step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
image_of() { compose config --format json | python3 -c "import json,sys; print(json.load(sys.stdin)['services']['$1']['image'])"; }

wait_http() {   # poll / from inside the container (python is in the image)
  for _ in $(seq 1 60); do
    if compose exec -T "$SVC" python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/', timeout=3)" >/dev/null 2>&1; then
      echo "$SVC healthy (http://localhost:8001/ inside the container)"; return 0
    fi
    sleep 1
  done
  echo "$SVC did not become healthy within 60 s" >&2; compose logs --tail 30 "$SVC" >&2; return 1
}

IMAGE=$(image_of "$SVC")
OLD_IMAGE=$(docker image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null || true)

step "$SVC: build $IMAGE ${NO_CACHE[*]}"
compose build "${NO_CACHE[@]}" "$SVC"

step "$SVC: import check"
compose run --rm -T --no-deps "$SVC" python -c "import app; print('imports ok:', app.app.name)"

step "$SVC: smoke tests in the new image"
compose run --rm -T --no-deps -v "$REPO/tests:/repo/tests:ro" -w /repo \
  -e DR_APP_DIR=/app -e PYTHONDONTWRITEBYTECODE=1 "$SVC" \
  python -m unittest discover -s tests -t . 2>&1 | grep -E "^Ran|^OK|FAIL|ERROR|Error"

step "$SVC: recreate"
compose up -d --no-deps --force-recreate "$SVC"

step "$SVC: health"
wait_http

step "$SVC: last 10 log lines"
compose logs --no-log-prefix --tail 10 "$SVC" | sed "s/^/[$SVC] /"

# gunicorn logs 0.0.0.0 (all interfaces) — not an address to open
PORT=$(compose port "$SVC" 8001 | sed 's/.*://')
step "$SVC: open http://127.0.0.1:${PORT}/  (or http://localhost:${PORT}/)"

NEW_IMAGE=$(docker image inspect -f '{{.Id}}' "$IMAGE")
if [ -n "$OLD_IMAGE" ] && [ "$OLD_IMAGE" != "$NEW_IMAGE" ]; then
  step "$SVC: remove the replaced image"
  docker image rm "$OLD_IMAGE" >/dev/null 2>&1 && echo "removed ${OLD_IMAGE:7:12}" \
    || echo "kept ${OLD_IMAGE:7:12} (still in use)"
fi
step "done"
