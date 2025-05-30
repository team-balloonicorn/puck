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
  users.attended_before as "attended previously",
  users.support_network as "support network",
  users.support_network_attended as "support network attended previously",
  users.dietary_requirements as "dietary requirements",
  users.accessibility_requirements as "access requirements",
  money.amount / 100 as "paid",
  money.paid_at as "paid at"
from users
join
  money on money.reference = users.payment_reference
order by "paid at";

.quit
EOF
