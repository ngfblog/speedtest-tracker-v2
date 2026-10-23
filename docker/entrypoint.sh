#!/bin/bash
# Entrypoint for speedtest-tracker on PHP 8.3.
# Replaces the old LinuxServer s6 init script (/etc/cont-init.d/50-speedtest).
# Differences from the old script: no "apk add composer" / "composer install"
# on start (vendor/ and the Ookla CLI are part of the image), and the cron
# daemon is replaced by a one-minute scheduler loop.

set -u

PUID="${PUID:-99}"
PGID="${PGID:-100}"

# --- Ookla EULA ---
if [ "${OOKLA_EULA_GDPR:-}" != "true" ]; then
    echo "Set the environment variable OOKLA_EULA_GDPR=true to accept the Ookla EULA and GDPR terms."
    exit 1
fi

# --- Runtime user "abc" with the requested PUID/PGID ---
grp=$(awk -F: -v g="$PGID" '$3==g {print $1; exit}' /etc/group)
if [ -z "$grp" ]; then
    addgroup -g "$PGID" abc
    grp=abc
fi
if ! id abc >/dev/null 2>&1; then
    adduser -D -H -u "$PUID" -G "$grp" -s /sbin/nologin abc
fi
sed -i "s/^user .*/user abc $grp;/" /etc/nginx/nginx.conf
printf '[www]\nuser = abc\ngroup = %s\n' "$grp" > /usr/local/etc/php-fpm.d/zzz-user.conf
# nginx workers run as abc and need its temp dirs for large FastCGI responses
chown -R abc:"$grp" /var/lib/nginx

run_as_abc() {
    su-exec abc env HOME=/config "$@"
}

# --- Copy the application code to the volume (same as the old image) ---
echo "Copying latest site files to config"
mkdir -p /config/www
# The old image ran "composer install" on start; drop that vendor/ so no stale packages remain
if [ -d /site/vendor ]; then
    rm -rf /config/www/vendor
fi
cp -rfT /site/ /config/www/

# --- Database ---
if [ ! -f /config/speed.db ]; then
    echo "Database file not found! Creating empty database"
    touch /config/speed.db
else
    echo "Database file exists"
fi
chown abc:"$grp" /config/speed.db

# --- .env ---
if [ ! -f /config/www/.env ]; then
    echo "Env file not found! Creating .env file"
    cp /site/.env.example /config/www/.env
else
    echo "Env file exists"
fi
sed -i "s,DB_DATABASE=.*,DB_DATABASE=/config/speed.db," /config/www/.env

# abc must own /config before any artisan call: SQLite writes its journal next to
# speed.db, and Laravel writes storage/ and bootstrap/cache/
mkdir -p /config/log/speedtest /config/www/storage/clockwork
chown -R abc:"$grp" /config

# --- Ookla CLI (built into /site/app/Bin, copied above by cp -rfT) ---
if [ -f /config/www/app/Bin/speedtest ]; then
    chmod +x /config/www/app/Bin/speedtest
    # Accept the license for HOME=/config (as the old image did) and for HOME=/config/www,
    # which is the HOME the app sets when it runs the CLI (config/speedtest.php)
    for home in /config /config/www; do
        su-exec abc env HOME="$home" timeout 5s /config/www/app/Bin/speedtest --accept-license --accept-gdpr > /dev/null 2>&1
    done
else
    echo "WARNING: /config/www/app/Bin/speedtest is missing, speedtests will fail"
fi

echo "Running database migrations"
run_as_abc php /config/www/artisan migrate --force

# --- App key and JWT secret ---
if grep -E "APP_KEY=[0-9A-Za-z:+\/=]{1,}" /config/www/.env > /dev/null; then
    echo "App key exists"
else
    echo "Generating app key"
    run_as_abc php /config/www/artisan key:generate
fi

if grep -E "JWT_SECRET=[0-9A-Za-z:+\/=]{1,}" /config/www/.env > /dev/null; then
    echo "JWT secret exists"
else
    echo "Generating JWT secret"
    run_as_abc php /config/www/artisan jwt:secret
fi

# --- Notifications ---
if [ -z "${SLACK_WEBHOOK+x}" ]; then
    echo "Slack webhook is unset"
    sed -i "s,SLACK_WEBHOOK=.*,SLACK_WEBHOOK=," /config/www/.env
else
    echo "Slack webhook set, updating db"
    sed -i "s,SLACK_WEBHOOK=.*,SLACK_WEBHOOK=$SLACK_WEBHOOK," /config/www/.env
    run_as_abc php /config/www/artisan speedtest:slack "$SLACK_WEBHOOK"
fi

if [ -z "${TELEGRAM_BOT_TOKEN+x}" ] && [ -z "${TELEGRAM_CHAT_ID+x}" ]; then
    echo "Telegram chat id and bot token unset"
    sed -i "s,TELEGRAM_BOT_TOKEN=.*,TELEGRAM_BOT_TOKEN=," /config/www/.env
    sed -i "s,TELEGRAM_CHAT_ID=.*,TELEGRAM_CHAT_ID=," /config/www/.env
else
    echo "Telegram chat id and bot token set, updating .env"
    # Only one of the two may be set; "set -u" would abort on the other
    sed -i "s,TELEGRAM_BOT_TOKEN=.*,TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}," /config/www/.env
    sed -i "s,TELEGRAM_CHAT_ID=.*,TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:-}," /config/www/.env
    run_as_abc php /config/www/artisan speedtest:telegram --chat="${TELEGRAM_CHAT_ID:-}" --bot="${TELEGRAM_BOT_TOKEN:-}"
fi

# --- Base path ---
if [ -z "${BASE_PATH+x}" ]; then
    echo "Base path is unset"
    sed -i "s,BASE_PATH=.*,BASE_PATH=," /config/www/.env
else
    echo "Base path set, updating .env"
    sed -i "s,BASE_PATH=.*,BASE_PATH=$BASE_PATH," /config/www/.env
fi

# --- Authentication ---
if [ -z "${AUTH+x}" ]; then
    echo "AUTH variable not set. Disabling authentication"
    run_as_abc php /config/www/artisan speedtest:auth --disable
elif [ "$AUTH" == "true" ]; then
    echo "AUTH variable set. Enabling authentication"
    run_as_abc php /config/www/artisan speedtest:auth --enable
else
    echo "AUTH variable set, but not to 'true'. Disabling authentication"
    run_as_abc php /config/www/artisan speedtest:auth --disable
fi

echo "Clearing old jobs from queue"
run_as_abc php /config/www/artisan queue:clear

# --- Folders and permissions (again: the sed -i calls above recreate .env as root) ---
chown -R abc:"$grp" /config
chmod -R 777 /config/www/storage/clockwork

# --- Start services ---
php-fpm -F &
nginx -g 'daemon off;' &
# Queue worker: runs the speedtest jobs (the old image ran it as an s6 service)
run_as_abc php /config/www/artisan queue:work --timeout=120 >> /config/log/speedtest/queue.log 2>&1 &

# Scheduler: run "artisan schedule:run" once at the start of every minute (replaces cron).
# Each run goes to the background so a long speedtest never skips the next minute.
(
    while true; do
        s=$(date +%S)
        sleep $((60 - 10#$s))
        run_as_abc php /config/www/artisan schedule:run >> /config/log/speedtest/cron.log 2>&1 &
    done
) &

trap 'kill $(jobs -p) 2>/dev/null; exit 0' TERM INT

# If php-fpm, nginx or the queue worker dies, exit so Docker restarts the container
wait -n
echo "A main process exited, stopping the container"
exit 1
