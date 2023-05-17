#!/bin/sh

set -eu

DB_FILE="$1"
CSV_FILE="$2"

sqlite3 "$DB_FILE" <<EOF
.headers on
.mode csv
.output $CSV_FILE

with money as (
  select reference, sum(amount) as amount
  from payments
  group by reference
)

select
  users.name as name,
  money.amount / 100 as paid,
  applications.answers ->> 'dietary-requirements' as diet
from users
join
  applications on applications.user_id = users.id
join
  money on money.reference = applications.payment_reference
where
  diet is not null
  and diet != ''
  and diet != 'I eat everything'
  and diet != 'N/A'
  and diet != 'N/a'
  and diet != 'Nada'
  and diet != 'No :)'
  and diet != 'No'
  and diet != 'No.'
  and diet != 'None'
  and diet != 'None, thank you x'
  and diet != 'Nope'
  and diet != 'none';

.quit
EOF
