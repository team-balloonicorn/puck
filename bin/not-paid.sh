#!/bin/sh

set -eu

# All the people who have filled in the form but not paid.

DB_FILE="$1"

sqlite3 "$DB_FILE" <<EOF
.bail on
.mode column

with money as (
  select reference, sum(amount) as amount
  from payments
  group by reference
)

select
  users.name as name
from users
inner join
  applications on applications.user_id = users.id
left join
  payments on payments.reference = applications.payment_reference
where
  payments.id is null;

.quit
EOF
