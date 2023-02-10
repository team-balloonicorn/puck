//// Facts about the event! FAQs and what have you!

import gleam/dynamic.{Dynamic} as dy
import gleam/option.{Option}
import gleam/result
import puck/database
import puck/error.{Error}
import sqlight

pub type Fact {
  Fact(id: Int, summary: String, detail: String, priority: Float)
}

pub fn list_all(db: database.Connection) -> Result(List(Fact), Error) {
  let sql =
    "
    select
      id, summary, detail, priority
    from
      facts
    order by
      priority desc,
      id asc
    limit
      1000
    "
  database.query(sql, db, [], decoder)
}

pub fn insert(
  conn: database.Connection,
  summary summary: String,
  detail detail: String,
  priority priority: Float,
) -> Result(Nil, Error) {
  let sql =
    "
    insert into facts
      (summary, detail, priority) 
    values
      (?1, ?2, ?3)
    "
  let arguments = [
    sqlight.text(summary),
    sqlight.text(detail),
    sqlight.float(priority),
  ]

  database.query(sql, conn, arguments, Ok)
  |> result.replace(Nil)
}

pub fn get(conn: database.Connection, id: Int) -> Result(Option(Fact), Error) {
  let sql =
    "
    select
      id, summary, detail, priority
    from
      facts
    where
      id = ?1
    "
  let arguments = [sqlight.int(id)]
  database.maybe_one(sql, conn, arguments, decoder)
}

pub fn update(conn: database.Connection, fact: Fact) -> Result(Nil, Error) {
  let sql =
    "
    update facts
    set
      summary = ?2,
      detail = ?3,
      priority = ?4
    where
      id = ?1
    "
  let arguments = [
    sqlight.int(fact.id),
    sqlight.text(fact.summary),
    sqlight.text(fact.detail),
    sqlight.float(fact.priority),
  ]

  database.query(sql, conn, arguments, Ok)
  |> result.replace(Nil)
}

fn decoder(data: Dynamic) {
  data
  |> dy.decode4(
    Fact,
    dy.element(0, dy.int),
    dy.element(1, dy.string),
    dy.element(2, dy.string),
    dy.element(3, dy.float),
  )
}
