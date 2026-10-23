#!/bin/bash
# Smoke test: start the image with an EMPTY /config volume and check that it
# creates speed.db, runs all migrations and answers HTTP 200 on port 80, and that
# the Ookla CLI is not in the image but is downloaded into /config on first start.
# Usage: docker/smoke-test.sh IMAGE [HOST_PORT]

set -euo pipefail

image="${1:?usage: smoke-test.sh IMAGE [HOST_PORT]}"
port="${2:-8080}"
name=speedtest-smoke
config="$(mktemp -d)"

docker rm -f "$name" > /dev/null 2>&1 || true
trap 'docker rm -f "$name" > /dev/null 2>&1 || true' EXIT

echo "== Ookla CLI must not be in the image"
set -x
docker run --rm --entrypoint sh "$image" -c 'ls -la /site/app/Bin'
{ set +x; } 2> /dev/null
if docker run --rm --entrypoint sh "$image" -c 'test -e /site/app/Bin/speedtest'; then
    echo "FAIL: /site/app/Bin/speedtest is in the image"
    exit 1
fi
if docker history --no-trunc --format '{{.CreatedBy}}' "$image" | grep -i 'install.speedtest.net'; then
    echo "FAIL: a build step downloads the Ookla CLI"
    exit 1
fi

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
grep -q 'Downloading Speedtest CLI' <<< "$(docker logs "$name" 2>&1)" || { echo "FAIL: Ookla CLI was not downloaded on start"; exit 1; }
docker exec "$name" test -x /config/www/app/Bin/speedtest || { echo "FAIL: /config/www/app/Bin/speedtest missing"; exit 1; }
echo "SMOKE TEST PASSED: no Ookla CLI in the image; empty /config -> CLI downloaded, speed.db created, all migrations ran, HTTP 200 on port 80"
