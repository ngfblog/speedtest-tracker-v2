#!/bin/bash
# Smoke test: start the image with an EMPTY /config volume and check that it
# creates speed.db, runs all migrations and answers HTTP 200 on port 80.
# Usage: docker/smoke-test.sh IMAGE [HOST_PORT]

set -euo pipefail

image="${1:?usage: smoke-test.sh IMAGE [HOST_PORT]}"
port="${2:-8080}"
name=speedtest-smoke
config="$(mktemp -d)"

docker rm -f "$name" > /dev/null 2>&1 || true
trap 'docker rm -f "$name" > /dev/null 2>&1 || true' EXIT

echo "== /config before start (must be empty)"
set -x
ls -A "$config"
docker run -d --name "$name" -p "$port:80" -v "$config:/config" -e OOKLA_EULA_GDPR=true "$image"
{ set +x; } 2> /dev/null

echo "== waiting for HTTP 200 on port $port"
code=000
for _ in $(seq 1 90); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" || true)"
    [ "$code" = 200 ] && break
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]; then
        echo "container stopped"
        break
    fi
    sleep 2
done

set -x
docker logs "$name"
curl -sS -o /dev/null -w 'GET / -> HTTP %{http_code}\n' "http://127.0.0.1:$port/"
curl -sS -o /dev/null -w 'GET /api/settings/config -> HTTP %{http_code}\n' "http://127.0.0.1:$port/api/settings/config"
docker exec "$name" ls -la /config /config/www/app/Bin
docker exec "$name" /config/www/app/Bin/speedtest --version
docker exec "$name" ls -la /config/.config/ookla /config/www/.config/ookla
docker exec "$name" su-exec abc php /config/www/artisan migrate:status
{ set +x; } 2> /dev/null

echo "== checks"
[ "$code" = 200 ] || { echo "FAIL: GET / returned $code"; exit 1; }
docker exec "$name" test -s /config/speed.db || { echo "FAIL: /config/speed.db missing or empty"; exit 1; }
status="$(docker exec "$name" su-exec abc php /config/www/artisan migrate:status)"
if ! grep -q 'Yes' <<< "$status" || grep -qE '\|\s*No\s*\|' <<< "$status"; then
    echo "FAIL: migrations did not all run"
    exit 1
fi
echo "SMOKE TEST PASSED: empty /config -> speed.db created, all migrations ran, HTTP 200 on port 80"
