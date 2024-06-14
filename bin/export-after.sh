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
select reference, sum(amount) as amount, min(created_at) as paid_at
  from payments
  group by reference
)

select
  users.name as name,
  users.email as email,
  applications.answers ->> 'support-network' as "support network",
  money.amount / 100 as "paid",
  money.paid_at as "paid at"
from users
join
  applications on applications.user_id = users.id
join
  money on money.reference = applications.payment_reference
order by "paid at";

.quit
EOF
