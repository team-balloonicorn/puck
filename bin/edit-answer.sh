#!/bin/sh

set -eu

DB_FILE="$1"
PERSON_ID="$2"
QUESTION="$3"
ANSWER="$4"

VALID_QUESTIONS=$(cat <<EOF
accessibility-requirements
dietary-requirements
pod-members
EOF
)

# Assert that the question is exactly one of the valid questions, printing an
# error message if not.
if ! echo "$VALID_QUESTIONS" | grep -q "^$QUESTION\$"; then
  echo "Invalid question: $QUESTION" >&2
  echo "Valid questions are:" $VALID_QUESTIONS >&2
  exit 1
fi

sqlite3 "$DB_FILE" <<EOF
.headers on
.mode line
.bail on

update applications
set answers = json_set(answers, '$.$QUESTION', '$ANSWER')
where user_id = $PERSON_ID
returning *;

.quit
EOF
