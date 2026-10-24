# Shared retention checks for smoke-test.sh and upgrade-test.sh (sourced, not executed).
# check_retention CONTAINER: copies the container's migrated /config/speed.db to a
# temporary database, seeds speedtests older and newer than 365 days into it, and runs
# "artisan speedtest:prune" against it (DB_DATABASE overrides the .env value). Checks
# that the guard refuses HISTORY_DAYS below 30, that --dry-run deletes nothing, that a
# real run deletes only the rows older than 365 days, and that the real
# /config/speed.db is untouched. Also checks that the command is scheduled.
# Returns non-zero if any check fails.

check_retention() {
    local name="$1" fail=0 dir tmp out real_before real_after
    # Runs SQL against a SQLite file inside the container; prints one value
    _sql() {
        docker exec "$name" php -r '$db = new PDO("sqlite:" . $argv[1]); echo $db->query($argv[2])->fetchColumn(), PHP_EOL;' "$1" "$2"
    }
    # Runs speedtest:prune against the temporary database; extra args are passed to docker exec
    _prune() {
        docker exec -e DB_DATABASE="$tmp" "$@" "$name" su-exec abc php /config/www/artisan speedtest:prune ${PRUNE_ARGS:-} 2>&1
    }

    real_before="$(_sql /config/speed.db 'SELECT COUNT(*) FROM speedtests')"
    # A private directory owned by abc: in sticky /tmp, fs.protected_regular stops even
    # root from opening a file another user owns for writing (SQLite then says "readonly")
    dir="$(docker exec "$name" su-exec abc mktemp -d)"
    tmp="$dir/retention-test.db"
    docker exec "$name" su-exec abc cp /config/speed.db "$tmp"
    # Old rows are tagged "old-*", rows to keep "keep-*"; 1 day of margin around the cutoff
    docker exec -i "$name" su-exec abc php -- "$tmp" <<'PHP' || { echo "FAIL: could not seed $tmp"; docker exec "$name" rm -rf "$dir"; return 1; }
<?php
$db = new PDO('sqlite:' . $argv[1]);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec('DELETE FROM speedtests');
$rows = ['old-800' => 800, 'old-400' => 400, 'old-366' => 366, 'keep-364' => 364, 'keep-30' => 30, 'keep-1' => 1, 'keep-0' => 0];
$insert = $db->prepare("INSERT INTO speedtests (ping, download, upload, created_at, updated_at, server_name, scheduled, failed)
                        VALUES (10, 100, 10, datetime('now', :age), datetime('now', :age), :name, 1, 0)");
foreach ($rows as $name => $days) {
    $insert->execute([':age' => '-' . $days . ' days', ':name' => $name]);
}
PHP
    echo "seeded: $(_sql "$tmp" "SELECT group_concat(server_name || '=' || created_at, ', ') FROM speedtests")"

    echo "-- guard: HISTORY_DAYS=29 and HISTORY_DAYS=abc must be refused"
    for bad in 29 abc; do
        if out="$(_prune -e HISTORY_DAYS="$bad")"; then
            echo "FAIL: HISTORY_DAYS=$bad was accepted: $out"; fail=1
        else
            echo "ok   refused HISTORY_DAYS=$bad: $out"
        fi
    done
    [ "$(_sql "$tmp" 'SELECT COUNT(*) FROM speedtests')" = 7 ] || { echo "FAIL: a refused run deleted rows"; fail=1; }

    echo "-- --dry-run must delete nothing"
    out="$(PRUNE_ARGS=--dry-run _prune)" || { echo "FAIL: dry run exited non-zero: $out"; fail=1; }
    echo "$out"
    grep -q ' 3 speedtests older than 365 days' <<< "$out" || { echo "FAIL: dry run did not report 3 rows"; fail=1; }
    [ "$(_sql "$tmp" 'SELECT COUNT(*) FROM speedtests')" = 7 ] || { echo "FAIL: dry run deleted rows"; fail=1; }

    echo "-- default run (HISTORY_DAYS unset = 365) must delete only the old rows"
    out="$(_prune)" || { echo "FAIL: prune exited non-zero: $out"; fail=1; }
    echo "$out"
    grep -q 'deleted 3 speedtests older than 365 days' <<< "$out" || { echo "FAIL: prune did not report 3 deleted rows"; fail=1; }
    [ "$(_sql "$tmp" "SELECT COUNT(*) FROM speedtests WHERE server_name LIKE 'old-%'")" = 0 ] || { echo "FAIL: old rows remain"; fail=1; }
    [ "$(_sql "$tmp" "SELECT COUNT(*) FROM speedtests WHERE server_name LIKE 'keep-%'")" = 4 ] || { echo "FAIL: rows newer than 365 days were deleted"; fail=1; }
    echo "left: $(_sql "$tmp" "SELECT group_concat(server_name, ', ') FROM speedtests")"

    echo "-- a second run deletes nothing"
    out="$(_prune)" || { echo "FAIL: second prune exited non-zero: $out"; fail=1; }
    grep -q 'deleted 0 speedtests' <<< "$out" || { echo "FAIL: second run: $out"; fail=1; }

    real_after="$(_sql /config/speed.db 'SELECT COUNT(*) FROM speedtests')"
    [ "$real_after" = "$real_before" ] || { echo "FAIL: /config/speed.db changed ($real_before -> $real_after rows)"; fail=1; }
    docker exec "$name" rm -rf "$dir"

    echo "-- speedtest:prune is scheduled daily at 03:30"
    out="$(docker exec "$name" su-exec abc php /config/www/artisan schedule:list 2>&1)" || true
    if grep 'speedtest:prune' <<< "$out" | grep -E '30 +3 +\* +\* +\*'; then
        echo "ok   scheduled"
    else
        echo "$out"; echo "FAIL: speedtest:prune is not scheduled at 30 3 * * *"; fail=1
    fi

    [ "$fail" -eq 0 ] && echo "ok   retention checks passed"
    return "$fail"
}
