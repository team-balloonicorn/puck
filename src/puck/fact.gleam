//// Facts about the event! FAQs and what have you!

import gleam/dynamic.{Dynamic} as dy
import gleam/option.{Option}
import gleam/result
import puck/database
import puck/error.{Error}
import sqlight

pub type Fact {
  Fact(
    id: Int,
    section_id: Int,
    summary: String,
    detail: String,
    priority: Float,
  )
}

pub type Section {
  Section(id: Int, title: String, blurb: String, priority: Float)
}

pub fn list_all(db: database.Connection) -> Result(List(Fact), Error) {
  let sql =
    "
    select
      id, section_id, summary, detail, priority
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

// TODO: test
pub fn list_for_section(
  db: database.Connection,
  section_id: Int,
) -> Result(List(Fact), Error) {
  let sql =
    "
    select
      id, section_id, summary, detail, priority
    from
      facts
    where
      section_id = ?1
    order by
      priority desc,
      id asc
    limit
      1000
    "
  database.query(sql, db, [sqlight.int(section_id)], decoder)
}

// TODO: test
pub fn list_all_sections(
  db: database.Connection,
) -> Result(List(Section), Error) {
  let sql =
    "
    select
      id, title, blurb, priority
    from
      fact_sections
    order by
      priority desc,
      id asc
    limit
      1000
    "
  database.query(sql, db, [], section_decoder)
}

pub fn insert(
  conn: database.Connection,
  section_id section_id: Int,
  summary summary: String,
  detail detail: String,
  priority priority: Float,
) -> Result(Nil, Error) {
  let sql =
    "
    insert into facts
      (section_id, summary, detail, priority) 
    values
      (?1, ?2, ?3, ?4)
    "
  let arguments = [
    sqlight.int(section_id),
    sqlight.text(summary),
    sqlight.text(detail),
    sqlight.float(priority),
  ]

  database.query(sql, conn, arguments, Ok)
  |> result.replace(Nil)
}

pub fn insert_section(
  conn: database.Connection,
  title title: String,
  blurb blurb: String,
) -> Result(Section, Error) {
  let sql =
    "
    insert into fact_sections
      (title, blurb, priority) 
    values
      (?1, ?2, ?3)
    returning
      id, title, blurb, priority
    "
  let arguments = [sqlight.text(title), sqlight.text(blurb), sqlight.float(0.1)]

  database.one(sql, conn, arguments, section_decoder)
}

pub fn get(conn: database.Connection, id: Int) -> Result(Option(Fact), Error) {
  let sql =
    "
    select
      id, section_id, summary, detail, priority
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
  |> dy.decode5(
    Fact,
    dy.element(0, dy.int),
    dy.element(1, dy.int),
    dy.element(2, dy.string),
    dy.element(3, dy.string),
    dy.element(4, dy.float),
  )
}

fn section_decoder(data: Dynamic) {
  data
  |> dy.decode4(
    Section,
    dy.element(0, dy.int),
    dy.element(1, dy.string),
    dy.element(2, dy.string),
    dy.element(3, dy.float),
  )
}
