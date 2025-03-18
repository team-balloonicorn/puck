#!/bin/sh

# Remove a payment that wasn't for midsummer

set -eu

DB_FILE="$1"
PAYMENT_ID="$2"

sqlite3 "$DB_FILE" <<EOF
.bail on
.headers on
.mode column

select * from payments
where id = '$PAYMENT_ID';

.quit
EOF
