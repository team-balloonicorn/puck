#!/bin/sh

set -eu

BACKUPS="/data/backups"
HOURLY="$BACKUPS/hourly-$(date -u +%H).sqlite3"
DAILY="$BACKUPS/daily-$(date -u +%d).sqlite3"
WEEKLY="$BACKUPS/weekly-$(date -u +%Y-%U).sqlite3"

mkdir -p "$BACKUPS"

rm -f "$HOURLY"
sqlite3 "$DATABASE_PATH" ".backup $HOURLY"

rm -f "$DAILY"
cp "$HOURLY" "$DAILY"

rm -f "$WEEKLY"
cp "$DAILY" "$WEEKLY"
