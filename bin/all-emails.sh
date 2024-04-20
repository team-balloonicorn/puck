#!/bin/sh

set -eu

# All the people who have paid

DB_FILE="$1"

sqlite3 "$DB_FILE" <<EOF
.bail on
.mode column

select distinct
  users.email as email
from users;

.quit
EOF
