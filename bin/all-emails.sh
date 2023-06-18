#!/bin/sh

set -eu

# All the people who have paid

DB_FILE="$1"

sqlite3 "$DB_FILE" <<EOF
.bail on
.mode column

with money as (
  select reference, sum(amount) as amount
  from payments
  group by reference
)

select distinct
  users.email as email
from users
inner join
  applications on applications.user_id = users.id
left join
  payments on payments.reference = applications.payment_reference
where
  payments.id is not null;

.quit
EOF
