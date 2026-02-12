# Speedtest Tracker - Fixed Version

Based on [henrywhitaker3/speedtest-tracker](https://github.com/henrywhitaker3/speedtest-tracker) with the following fixes:

## Fixes

- **Date format**: Changed from MM/DD/YY to DD/MM/YY in all graphs and tables
- **History graph**: Now correctly shows more than 7 days of data

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
  --restart unless-stopped \
  speedtest-fixed
```

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
