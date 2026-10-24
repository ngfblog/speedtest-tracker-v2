# Shared HTTP checks for smoke-test.sh and upgrade-test.sh (sourced, not executed).
# check_http BASE_URL: fetches "/", then requires HTTP 200 and a non-empty body for
# every <script src> and <link href> path in the page and for the main API endpoints,
# that the built app.js has no hardcoded "NaN" values, HTTP 404 for the
# disabled self-updater endpoints, and that the days endpoints accept only 1..365.
# Needs at least one speedtest row (/api/speedtest/latest is 404 on an empty table).
# Returns non-zero if any check fails.

check_http() {
    local base="$1" fail=0 page path code size
    local -a paths
    page="$(curl -sS "$base/")"
    mapfile -t paths < <(
        grep -oiE '<(script|link)[^>]+(src|href)="[^"]+"' <<< "$page" \
            | sed -E 's/.*(src|href)="([^"]+)"/\2/' \
            | grep '^/' | sort -u
    )
    if [ "${#paths[@]}" -eq 0 ]; then
        echo "FAIL: no <script src> / <link href> paths found in GET /"
        return 1
    fi
    for path in "${paths[@]}" /api/speedtest/latest /api/speedtest/time/7 /api/speedtest/home/7 /api/speedtest/fail/7 \
        /api/speedtest/time/365 /api/speedtest/fail/365 /api/speedtest/home/365 /api/speedtest/home/1 /api/settings/config; do
        read -r code size < <(curl -s -o /dev/null -w '%{http_code} %{size_download}' "$base$path" || echo "000 0")
        if [ "$code" = 200 ] && [ "${size%.*}" -gt 0 ]; then
            echo "ok   $code ${size%.*} bytes  $path"
        else
            echo "FAIL $code ${size%.*} bytes  $path"
            fail=1
        fi
    done
    # The built bundle must not contain hardcoded placeholder values
    local bundle found=0
    for path in "${paths[@]}"; do
        case "$path" in */js/app.js|*/js/app.js\?*) ;; *) continue ;; esac
        found=1
        bundle="$(curl -s "$base$path")"
        if grep -qF -e 'NaN ms (average)' -e 'NaN Mbit/s' <<< "$bundle"; then
            echo "FAIL hardcoded \"NaN\" values in  $path"
            fail=1
        else
            echo "ok   no hardcoded \"NaN\" values in  $path"
        fi
    done
    [ "$found" = 1 ] || { echo "FAIL: /js/app.js is not referenced by GET /"; fail=1; }
    # The in-app self-updater is disabled
    for path in /api/update/check /api/update/download /api/update/extract /api/update/move; do
        code="$(curl -s -o /dev/null -w '%{http_code}' "$base$path" || echo 000)"
        if [ "$code" = 404 ]; then
            echo "ok   $code (updater disabled)  $path"
        else
            echo "FAIL $code (expected 404)  $path"
            fail=1
        fi
    done
    # The days endpoints reject values outside 1..365 with a validation error
    for path in /api/speedtest/time/366 /api/speedtest/fail/366 /api/speedtest/home/366 \
        /api/speedtest/home/0 /api/speedtest/home/-1 /api/speedtest/home/7.5 /api/speedtest/home/abc; do
        code="$(curl -s -o /dev/null -w '%{http_code}' "$base$path" || echo 000)"
        if [ "$code" = 422 ]; then
            echo "ok   $code (days out of range)  $path"
        else
            echo "FAIL $code (expected 422)  $path"
            fail=1
        fi
    done
    return "$fail"
}
