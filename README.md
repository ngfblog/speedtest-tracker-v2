# Speedtest Tracker - Fixed Version

A maintained fork of the original Speedtest Tracker (GPL-3.0, see [NOTICE.md](NOTICE.md)) with the following fixes:

## Fixes

- **Date format**: Changed from MM/DD/YY to DD/MM/YY in all graphs and tables
- **History graph**: Now correctly shows more than 7 days of data
- **History range**: pick 1, 7, 14, 30, 60, 90, 180 or 365 days from a list (default 30); the API accepts only 1..365 days
- **Retention**: speedtests older than `HISTORY_DAYS` (default 365) are pruned daily
- **No in-app self-updater**: updates come from the Docker image; the `api/update/check|download|extract|move` endpoints return 404
- **Runtime**: PHP 8.3 (official `php:8.3-fpm-alpine` image, PHP >= 8.3.36) + nginx instead of the
  PHP 7.4 image the upstream project ships. The build fails if the PHP version is older than 8.3.36.

## Image

The image is built from this repository by GitHub Actions and pushed to Docker Hub as
`nirgf/speedtest-tracker-v2` with the tags:

- `latest` = `php83` - the current PHP 8.3 build of `master`, rebuilt weekly for security updates
- `php83-YYYYMMDD` - build of that date

`latest` used to be the old PHP 7.4 image; it now points to the same image as `php83`.

## Quick Start

### Option 1 - Docker Compose (recommended)

```bash
docker compose up -d
```

Open http://localhost:8766

### Option 2 - Build manually

```bash
docker build -t speedtest-fixed .
docker run -d \
  --name speedtest \
  -p 8766:80 \
  -v ./data:/config \
  -e OOKLA_EULA_GDPR=true \
  -e PUID=1000 -e PGID=1000 \
  --restart unless-stopped \
  speedtest-fixed
```

### Option 3 - Pre-built image

```bash
docker run -d \
  --name speedtest \
  -p 8766:80 \
  -v ./data:/config \
  -e OOKLA_EULA_GDPR=true \
  --restart unless-stopped \
  nirgf/speedtest-tracker-v2:latest
```

## Configuration

| Setting | Description |
| --- | --- |
| Port `80` | Web UI (map it to any host port, e.g. `-p 8766:80`) |
| Volume `/config` | All data: `speed.db`, `www/` (app copy and `.env`), `log/` |
| `OOKLA_EULA_GDPR=true` | **Required.** Accepts the Ookla EULA and GDPR terms; the container exits without it |
| `PUID` / `PGID` | User and group IDs that own `/config` and run the app (default `99` / `100`) |
| `TZ` | Time zone, e.g. `Asia/Jerusalem` (default `UTC`) |
| `HISTORY_DAYS` | Keep this many days of speedtests (default `365`, minimum `30`); older rows are deleted daily at 03:30 (`TZ`) by `artisan speedtest:prune` |
| `AUTH=true` | Enable authentication |
| `SLACK_WEBHOOK` | Slack webhook URL for notifications |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` | Telegram notifications |
| `BASE_PATH` | Base path when served from a sub-path behind a reverse proxy |

Moving from the old PHP 7.4 image: keep the same `/config` volume. On start the container
copies the new app code (including a fresh `vendor/`) over `/config/www` and keeps `speed.db` and `.env`.

## Data persistence

All data is stored in the `./data` folder.

## Backup

```bash
# Backup data
docker cp speedtest:/config ./backup-config

# Backup image
docker save speedtest-fixed -o speedtest-fixed-backup.tar
```

## Restore

```bash
# Restore image
docker load -i speedtest-fixed-backup.tar

# Restore data
docker cp ./backup-config/. speedtest:/config
```

## License

GPL-3.0, like the upstream project. See [LICENSE](LICENSE). Credits for the upstream project and the bundled
MIT packages in `packages/` are in [NOTICE.md](NOTICE.md).
