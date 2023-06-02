#!/bin/sh

set -eu

echo Running at $(date -u)

REMOTE="/data/backups"
HOURLY="hourly-$(date -u +%H).sqlite3"
DAILY="daily-$(date -u +%d).sqlite3"
WEEKLY="weekly-$(date -u +%Y-%U).sqlite3"
LOCAL="$HOME/backups/puck"

mkdir -p "$LOCAL"
fly ssh console --command "sh -e /app/bin/locally-backup-database.sh"

rm -f "$LOCAL/$HOURLY"
fly ssh sftp get "$REMOTE/$HOURLY" "$LOCAL/$HOURLY"

rm -f "$LOCAL/$DAILY"
fly ssh sftp get "$REMOTE/$DAILY" "$LOCAL/$DAILY"

[ -f "$LOCAL/$WEEKLY" ] || fly ssh sftp get "$REMOTE/$WEEKLY" "$LOCAL/$WEEKLY"

echo "Done."
