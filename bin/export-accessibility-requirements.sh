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
  users.email as email,
  money.amount is not null and money.amount > 0 as "has paid",
  users.accessibility_requirements as access
from users
left join
  money on money.reference = users.payment_reference
where
  access is not null
  and access != ''
  and access != 'N/A'
  and access != 'N/a'
  and access != 'Nada'
  and access != 'No :)'
  and access != 'No'
  and access != 'No '
  and access != 'No.'
  and access != 'None'
  and access != 'None.'
  and access != 'None, thank you x'
  and access != 'None, thank you'
  and access != 'No, thank you'
  and access != 'I''m all good'
  and access != 'Not that I can think of, thank you! '
  and access != 'None!'
  and access != 'None :)'
  and access != 'At this current point in time, I don’t think so'
  and access != 'Nope'
  and access != 'No - happy to help others if assistance is required!'
  and access != 'none';

.quit
EOF
