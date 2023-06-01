#!/bin/sh

# Some people use the wrong reference with their payment. This fixes it.

set -eu

DB_FILE="$1"
PAYMENT_ID="$2"
NEW_REFERENCE="$3"

sqlite3 "$DB_FILE" <<EOF
.bail on
.headers on
.mode column

update payments
set reference = '$NEW_REFERENCE'
where id = '$PAYMENT_ID'
returning *;

.quit
EOF
