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
  users.name as name,
  case when money.amount > 0 then 'Yes' else 'No' end as paid,
  applications.answers ->> 'attended' as "attended before",
  applications.answers ->> 'pod-members' as "support network"
from users
join
  applications on applications.user_id = users.id
left join
  money on money.reference = applications.payment_reference;

.quit
EOF
