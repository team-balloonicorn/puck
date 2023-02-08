import sqlight.{ConstraintPrimarykey, SqlightError}
import gleam/list
import gleam/json
import gleam/string.{lowercase} as stringmod
import gleam/result
import gleam/dynamic.{Dynamic, element, field, int, string}
import puck/error.{Error}
import puck/database
import utility
import gleam/pair

pub type Payment {
  Payment(
    id: String,
    created_at: String,
    counterparty: String,
    amount: Int,
    reference: String,
  )
}

pub fn from_json(json: String) -> Result(Payment, json.DecodeError) {
  let decoder =
    dynamic.decode5(
      Payment,
      field("data", field("id", string)),
      field("data", field("created", string)),
      field(
        "data",
        dynamic.any([
          field("counterparty", field("name", string)),
          field("merchant", field("name", string)),
        ]),
      ),
      field("data", field("amount", int)),
      field(
        "data",
        dynamic.any([field("notes", string), field("description", string)]),
      ),
    )

  use payment <- result.map(json.decode(from: json, using: decoder))
  Payment(..payment, reference: lowercase(payment.reference))
}

fn decoder(data: Dynamic) -> Result(Payment, List(dynamic.DecodeError)) {
  data
  |> dynamic.decode5(
    Payment,
    element(0, string),
    element(1, string),
    element(2, string),
    element(3, int),
    element(4, string),
  )
}

pub fn insert(
  conn: database.Connection,
  payment: Payment,
) -> Result(Bool, Error) {
  use <- utility.guard(when: payment.amount <= 0, return: Ok(False))

  let sql =
    "
    insert into payments (
      id,
      created_at,
      counterparty,
      amount,
      reference
    ) values (
      ?1, ?2, ?3, ?4, ?5
    )
    "

  let arguments = [
    sqlight.text(payment.id),
    sqlight.text(payment.created_at),
    sqlight.text(payment.counterparty),
    sqlight.int(payment.amount),
    sqlight.text(lowercase(payment.reference)),
  ]

  case database.query(sql, conn, arguments, Ok) {
    Ok(_) -> Ok(True)
    Error(error.Database(SqlightError(ConstraintPrimarykey, _, _))) -> Ok(False)
    Error(e) -> Error(e)
  }
}

pub fn list_all(conn: database.Connection) -> Result(List(Payment), Error) {
  let sql =
    "
    select
      id,
      created_at,
      counterparty,
      amount,
      reference
    from payments
    limit 1000
    "

  database.query(sql, conn, [], decoder)
}

pub fn for_reference(
  conn: database.Connection,
  reference: String,
) -> Result(List(Payment), Error) {
  let sql =
    "
    select
      id,
      created_at,
      counterparty,
      amount,
      reference
    from payments
    where reference = ?1
    "

  database.query(sql, conn, [sqlight.text(reference)], decoder)
}

pub fn total_for_reference(
  conn: database.Connection,
  reference: String,
) -> Result(Int, Error) {
  let sql =
    "
    select
      coalesce(sum(amount), 0) as total
    from
      payments
    where
      reference = ?1
    "

  database.one(
    sql,
    conn,
    [sqlight.text(reference)],
    dynamic.element(0, dynamic.int),
  )
}

/// Get the total amount of payments which have been linked to an attendee.
pub fn total(conn: database.Connection) -> Result(Int, Error) {
  let sql =
    "
    select
      coalesce(sum(amount), 0) as total
    from
      payments
    inner join applications on
      payments.reference = applications.payment_reference
    "

  database.one(sql, conn, [], dynamic.element(0, dynamic.int))
}

// TODO: test
pub fn unmatched(conn: database.Connection) -> Result(List(Payment), Error) {
  let sql =
    "
    select
      payments.id,
      created_at,
      counterparty,
      amount,
      reference
    from
      payments
    left join applications on
      payments.reference = applications.payment_reference
    where
      applications.id is null
    "

  database.query(sql, conn, [], decoder)
}

// TODO: test
/// Show the amount transferred per day over the last N months.
pub fn per_day(
  conn: database.Connection,
) -> Result(List(#(String, Int, Int)), Error) {
  let sql =
    "
    with recursive dates as (
      select
        date('now', '-3 month') as date
      union all
      select
        date(date, '+1 day')
      from
        dates
      where
        date < date('now')
    ),

    matched_payments as (
      select
        payments.amount,
        payments.created_at
      from
        payments
      inner join applications on
        payments.reference = applications.payment_reference
    )

    select
      date,
      coalesce(sum(amount), 0) as daily_total
    from
      dates
    left join matched_payments as payments on
       payments.created_at >= dates.date and
       payments.created_at < date(dates.date, '+1 day')
    group by
      date
    order by
      date asc
    "
  let decoder = dynamic.tuple2(string, int)
  use rows <- result.then(database.query(sql, conn, [], decoder))
  rows
  |> list.drop_while(fn(row) { row.1 == 0 })
  |> list.map_fold(
    0,
    fn(total, row) {
      let total = total + row.1
      #(total, #(row.0, row.1, total))
    },
  )
  |> pair.second
  |> list.reverse
  |> Ok
}
