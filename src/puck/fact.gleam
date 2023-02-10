//// Facts about the event! FAQs and what have you!

import gleam/dynamic.{Dynamic} as dy
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
