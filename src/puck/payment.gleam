import sqlight
import gleam/json
import gleam/result
import gleam/dynamic.{Dynamic, element, field, int, string}
import puck/error.{Error}
import puck/database
import utility

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

  json.decode(from: json, using: decoder)
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

pub fn insert(conn: database.Connection, payment: Payment) -> Result(Nil, Error) {
  use <- utility.guard(when: payment.amount <= 0, return: Ok(Nil))

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
    on conflict (id) do nothing
    "

  let arguments = [
    sqlight.text(payment.id),
    sqlight.text(payment.created_at),
    sqlight.text(payment.counterparty),
    sqlight.int(payment.amount),
    sqlight.text(payment.reference),
  ]

  database.query(sql, conn, arguments, Ok)
  |> result.map(fn(_) { Nil })
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
