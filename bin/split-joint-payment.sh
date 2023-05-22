#!/bin/sh

# Some people use their payment reference to pay for multiple people. This means
# the other people show up as having not been paid.
#
# This script creates a new copy of the payment with half the money and a new
# reference. The original payment is updated to have the other half of the money
# also.

set -eu

DB_FILE="$1"
PAYMENT_ID="$2"
NEW_REFERENCE="$3"

sqlite3 "$DB_FILE" <<EOF
.bail on

begin;

insert into payments (
  id, created_at, counterparty, amount, reference
)
select
  id || '-split' as id,
  created_at,
  counterparty,
  amount / 2 as amount,
  '$NEW_REFERENCE' as reference
from payments where id = '$PAYMENT_ID';

update payments
set amount = amount / 2
where id = '$PAYMENT_ID';

select * from payments where id like '$PAYMENT_ID%';

commit;
.quit
EOF
