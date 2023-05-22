#!/bin/sh

set -eu

DB_FILE="$1"
REFERENCE="$2"

sqlite3 "$DB_FILE" <<EOF
.headers on
.mode column

select * from payments where reference = '$REFERENCE';

.quit
EOF
