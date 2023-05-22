#!/bin/sh

set -eu

# All the people who have filled in the form but not paid.

DB_FILE="$1"
# CSV_FILE="$2"

# .output $CSV_FILE
sqlite3 "$DB_FILE" <<EOF
.bail on
.mode column
--.headers on
--.mode csv

with money as (
  select reference, sum(amount) as amount
  from payments
  group by reference
)

select
  users.name as name--,
  --users.email as email,
  --applications.answers ->> 'pod-members' as pod,
  --applications.answers ->> 'attended' as attended,
  --applications.answers ->> 'accessibility-requirements' as access,
  --applications.answers ->> 'dietary-requirements' as diet
from users
inner join
  applications on applications.user_id = users.id
left join
  payments on payments.reference = applications.payment_reference
where
  payments.id is null;

.quit
EOF
