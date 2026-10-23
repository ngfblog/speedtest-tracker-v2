#!/bin/bash
# Upgrade test: initialise an empty /config with the OLD image, add a marker
# speedtest row, stop it, then start the NEW image on the same volume and check
# HTTP 200, no PHP fatal errors, migrations OK and the old data still present.
# Usage: docker/upgrade-test.sh OLD_IMAGE NEW_IMAGE [HOST_PORT]

set -euo pipefail

old_image="${1:?usage: upgrade-test.sh OLD_IMAGE NEW_IMAGE [HOST_PORT]}"
new_image="${2:?usage: upgrade-test.sh OLD_IMAGE NEW_IMAGE [HOST_PORT]}"
port="${3:-8081}"
old=speedtest-upgrade-old
new=speedtest-upgrade-new
config="$(mktemp -d)"

cleanup() { docker rm -f "$old" "$new" > /dev/null 2>&1 || true; }
cleanup
trap cleanup EXIT

# Waits for HTTP 200 on / while the container runs; $1 = container, $2 = timeout in seconds
wait_http_200() {
    local deadline=$((SECONDS + $2)) code=000
    while [ "$SECONDS" -lt "$deadline" ]; do
        code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" || true)"
        [ "$code" = 200 ] && return 0
        [ "$(docker inspect -f '{{.State.Running}}' "$1")" = true ] || break
        sleep 5
    done
    echo "FAIL: $1 did not answer HTTP 200 (last code $code)"
    docker logs "$1" 2>&1 | tail -n 80
    return 1
}

# Runs SQL against /config/speed.db inside a container with PHP's PDO; prints one value
sql() {
    docker exec "$1" php -r '$db = new PDO("sqlite:/config/speed.db"); echo $db->query($argv[1])->fetchColumn(), PHP_EOL;' "$2"
}

echo "== 1. old image on an empty volume"
set -x
ls -A "$config"
docker run -d --name "$old" -p "$port:80" -v "$config:/config" -e OOKLA_EULA_GDPR=true "$old_image"
{ set +x; } 2> /dev/null
# The old image runs "apk add composer" and "composer install" on first start
wait_http_200 "$old" 900
docker logs "$old" 2>&1 | tail -n 25

echo "== 2. marker row and counts in the old database"
docker exec -i "$old" php <<'PHP'
<?php
$db = new PDO('sqlite:/config/speed.db');
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec("INSERT INTO speedtests (ping, download, upload, created_at, updated_at, server_name, scheduled, failed)
           VALUES (12.34, 567.89, 98.76, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'upgrade-test-marker', 0, 0)");
PHP
old_speedtests="$(sql "$old" 'SELECT COUNT(*) FROM speedtests')"
old_settings="$(sql "$old" 'SELECT COUNT(*) FROM settings')"
old_migrations="$(sql "$old" 'SELECT COUNT(*) FROM migrations')"
old_app_key="$(docker exec "$old" grep '^APP_KEY=' /config/www/.env)"
echo "speedtests=$old_speedtests settings=$old_settings migrations=$old_migrations"
docker exec "$old" ls -la /config/www/bootstrap/cache
log_lines="$(docker exec "$old" sh -c 'cat /config/www/storage/logs/*.log 2> /dev/null | wc -l')"

echo "== 3. stop the old image"
set -x
docker stop "$old"
docker rm "$old"
docker run -d --name "$new" -p "$port:80" -v "$config:/config" -e OOKLA_EULA_GDPR=true "$new_image"
{ set +x; } 2> /dev/null

echo "== 4. new image on the same volume"
wait_http_200 "$new" 180
sleep 5
logs="$(docker logs "$new" 2>&1)"
echo "$logs"
set -x
curl -sS -o /dev/null -w 'GET / -> HTTP %{http_code}\n' "http://127.0.0.1:$port/"
curl -sS -o /dev/null -w 'GET /api/speedtest/latest -> HTTP %{http_code}\n' "http://127.0.0.1:$port/api/speedtest/latest"
docker exec "$new" ls -la /config/www/bootstrap/cache
docker exec "$new" su-exec abc php /config/www/artisan migrate:status
{ set +x; } 2> /dev/null
new_logs="$(docker exec "$new" sh -c 'cat /config/www/storage/logs/*.log 2> /dev/null || true' | tail -n +"$((log_lines + 1))")"

echo "== checks"
fail=0
[ "$(docker inspect -f '{{.State.Running}}' "$new")" = true ] || { echo "FAIL: new container is not running"; fail=1; }
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")"
[ "$code" = 200 ] || { echo "FAIL: GET / returned $code"; fail=1; }
fatal='PHP (Fatal|Parse) error|Fatal error|Uncaught|Class "?[A-Za-z\\]+"? not found|ErrorException|In [A-Za-z]+\.php line [0-9]+'
if grep -E "$fatal" <<< "$logs"; then echo "FAIL: PHP errors in the container log"; fail=1; fi
if grep -E '\.(ERROR|CRITICAL|EMERGENCY)' <<< "$new_logs"; then echo "FAIL: new errors in storage/logs"; fail=1; fi
status="$(docker exec "$new" su-exec abc php /config/www/artisan migrate:status)" || { echo "FAIL: migrate:status failed"; fail=1; }
if ! grep -q 'Yes' <<< "$status" || grep -qE '\|\s*No\s*\|' <<< "$status"; then echo "FAIL: migrations not all run"; fail=1; fi
new_speedtests="$(sql "$new" 'SELECT COUNT(*) FROM speedtests')"
new_settings="$(sql "$new" 'SELECT COUNT(*) FROM settings')"
new_migrations="$(sql "$new" 'SELECT COUNT(*) FROM migrations')"
marker="$(sql "$new" "SELECT COUNT(*) FROM speedtests WHERE server_name = 'upgrade-test-marker' AND download = 567.89")"
new_app_key="$(docker exec "$new" grep '^APP_KEY=' /config/www/.env)"
echo "after upgrade: speedtests=$new_speedtests settings=$new_settings migrations=$new_migrations marker=$marker"
[ "$new_speedtests" = "$old_speedtests" ] || { echo "FAIL: speedtests $old_speedtests -> $new_speedtests"; fail=1; }
[ "$new_settings" -ge "$old_settings" ] || { echo "FAIL: settings $old_settings -> $new_settings"; fail=1; }
[ "$new_migrations" -ge "$old_migrations" ] || { echo "FAIL: migrations $old_migrations -> $new_migrations"; fail=1; }
[ "$marker" = 1 ] || { echo "FAIL: marker row missing"; fail=1; }
[ "$new_app_key" = "$old_app_key" ] || { echo "FAIL: APP_KEY changed"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo "UPGRADE TEST PASSED: $old_image volume -> $new_image: HTTP 200, no PHP fatals, migrations OK, old rows and APP_KEY kept"
