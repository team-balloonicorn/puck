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
  money.amount is not null and money.amount > 0 as "has paid",
  users.dietary_requirements as diet
from users
join
  money on money.reference = users.payment_reference
where
  diet is not null
  and diet != ''
  and diet != 'I eat everything'
  and diet != 'N/A'
  and diet != 'N/a'
  and diet != 'Nada'
  and diet != 'No :)'
  and diet != 'No'
  and diet != 'no'
  and diet != 'No.'
  and diet != 'None'
  and diet != 'none'
  and diet != 'None, thank you x'
  and diet != 'Nope'
  and diet != 'No, thank you'
  and diet != 'Nope!'
  and diet != 'NA!'
  and diet != 'none';

.quit
EOF
