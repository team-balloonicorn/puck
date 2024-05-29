#!/bin/sh

set -eu

DB_FILE="$1"
CSV_FILE="$2"

sqlite3 "$DB_FILE" <<EOF
.headers on
.mode csv
.bail on
.output $CSV_FILE

with money as (
  select reference, sum(amount) as amount
  from payments
  group by reference
)

select
  users.email as email,
  users.name as name
from users
left join
  applications on applications.user_id = users.id
left join
  money on money.reference = applications.payment_reference
where
  money.reference is null
order by name;

.quit
EOF
