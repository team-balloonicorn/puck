#!/bin/sh

set -eu

BACKUPS="/data/backups"
HOURLY="$BACKUPS/hourly-$(date +%H).sqlite3"
DAILY="$BACKUPS/daily-$(date +%d).sqlite3"
WEEKLY="$BACKUPS/weekly-$(date +%Y-%U).sqlite3"

mkdir -p "$BACKUPS"

rm -f "$HOURLY"
sqlite3 "$DATABASE_PATH" ".backup $HOURLY"

rm -f "$DAILY"
cp "$HOURLY" "$DAILY"

rm -f "$WEEKLY"
cp "$DAILY" "$WEEKLY"
