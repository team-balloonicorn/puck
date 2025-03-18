#!/bin/sh

# Get a payment

set -eu

DB_FILE="$1"
PAYMENT_ID="$2"

sqlite3 "$DB_FILE" <<EOF
.bail on
.headers on
.mode column

delete from payments
where id = '$PAYMENT_ID'
returning *;

.quit
EOF
