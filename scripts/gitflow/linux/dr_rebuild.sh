#!/usr/bin/env bash
# Rebuild this branch's Docker stack and check it end to end with curl.
#
#   linux/dr_rebuild.sh [--no-cache] [--check-only]
#   linux/dr_rebuild.sh --help
#
#   --no-cache     build without the Docker layer cache
#   --check-only   skip build and recreate; only run the end-to-end curl check
#   --help         show this help
#
# Works with either compose file, using WEB_SERVICE / APP_PORT / IMAGE_TEST_CMD
# from gitflow.conf:
#   local compose (master, dev/*, stage-* — no nginx service):
#     1. build the new WEB_SERVICE image (the old container keeps running)
#     2. IMAGE_TEST_CMD in a throw-away container of the new image (if set);
#        a failure stops here, the running container is untouched
#     3. recreate the container
#     4. curl http://127.0.0.1:<host port>/ until it answers 200 (60 s)
#     5. last 10 log lines; remove the replaced image
#   prod compose (deploy branch on the VPS — has an nginx service):
#     same build and test, then docker compose up -d for the whole stack, and
#     curl https://<server_name>/ (expect 200) and http://<server_name>/ (expect 301),
#     server_name read from nginx/default.conf
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NO_CACHE=(); CHECK_ONLY=""
for arg in "$@"; do
  case "$arg" in
    --no-cache) NO_CACHE=(--no-cache) ;;
    --check-only) CHECK_ONLY=1 ;;
    --help|-h) gf_help; exit 0 ;;
    *) gf_help >&2; exit 2 ;;
  esac
done

gf_root
gf_load_conf
need_cmd docker
need_cmd curl
compose() { docker compose -f docker-compose.yaml --project-directory . "$@"; }

# http_code <url>  -> the status code, 000 when nothing answers
http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1" || true; }

# wait_for <url> <code> <seconds>
wait_for() {
  local c=""
  for _ in $(seq 1 "$3"); do
    c="$(http_code "$1")"
    [ "$c" = "$2" ] && { echo "  $1 -> $c"; return 0; }
    sleep 1
  done
  echo "  $1 -> $c (expected $2)" >&2; return 1
}

PROD=""
compose config --services | grep -qx nginx && PROD=1

if [ -z "$CHECK_ONLY" ]; then
  OLD_IMAGE="$(compose images -q "$WEB_SERVICE" 2>/dev/null | head -n 1 || true)"

  info "$WEB_SERVICE: build ${NO_CACHE[*]:-}"
  compose build ${NO_CACHE[@]+"${NO_CACHE[@]}"} "$WEB_SERVICE"

  if [ -n "$IMAGE_TEST_CMD" ]; then
    info "$WEB_SERVICE: tests in the new image"
    compose run --rm -T --no-deps "$WEB_SERVICE" sh -c "$IMAGE_TEST_CMD"
  fi

  if [ -n "$PROD" ]; then
    info "stack: up (prod compose)"
    compose up -d
  else
    info "$WEB_SERVICE: recreate"
    compose up -d --no-deps --force-recreate "$WEB_SERVICE"
  fi
fi

info "end-to-end check"
if [ -n "$PROD" ]; then
  [ -f nginx/default.conf ] || die "nginx/default.conf not found"
  DOMAIN="$(awk '$1 == "server_name" { gsub(/;/, "", $2); print $2; exit }' nginx/default.conf)"
  [ -n "$DOMAIN" ] || die "no server_name in nginx/default.conf"
  wait_for "https://$DOMAIN/" 200 30 && wait_for "http://$DOMAIN/" 301 10 \
    || { compose ps; compose logs --tail 30 >&2; die "end-to-end check failed"; }
else
  PORT="$(compose port "$WEB_SERVICE" "$APP_PORT" 2>/dev/null | sed 's/.*://' || true)"
  [ -n "$PORT" ] || die "$WEB_SERVICE publishes no host port for $APP_PORT — is it running?"
  wait_for "http://127.0.0.1:$PORT/" 200 60 \
    || { compose logs --tail 30 "$WEB_SERVICE" >&2; die "$WEB_SERVICE did not answer 200 within 60 s"; }
fi

[ -n "$CHECK_ONLY" ] && exit 0
info "$WEB_SERVICE: last 10 log lines"
compose logs --no-log-prefix --tail 10 "$WEB_SERVICE" | sed "s/^/[$WEB_SERVICE] /"

NEW_IMAGE="$(compose images -q "$WEB_SERVICE" 2>/dev/null | head -n 1 || true)"
if [ -n "$OLD_IMAGE" ] && [ "$OLD_IMAGE" != "$NEW_IMAGE" ]; then
  info "$WEB_SERVICE: remove the replaced image"
  docker image rm "$OLD_IMAGE" >/dev/null 2>&1 && echo "removed ${OLD_IMAGE:0:12}" || echo "kept ${OLD_IMAGE:0:12} (still in use)"
fi
[ -n "$PROD" ] || info "open http://127.0.0.1:${PORT}/"
info "done"
