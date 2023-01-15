import sqlight
import puck/error.{Error}
import puck/database
import gleam/dynamic.{Dynamic}
import gleam/result

pub type User {
  User(id: Int, email: String, interactions: Int)
}

pub fn get_or_insert_by_email(
  conn: sqlight.Connection,
  email: String,
) -> Result(User, Error) {
  let sql =
    "
    insert into users (email) 
      values (?)
    on conflict (email) do 
      update set email = email
    returning *
    "
  database.one(sql, conn, [sqlight.text(email)], decoder)
}

pub fn increment_interaction_count(
  conn: sqlight.Connection,
  user_id: Int,
) -> Result(Nil, Error) {
  let sql =
    "
    update users
    set interactions = interactions + 1
    where id = ?
    "
  database.query(sql, conn, [sqlight.int(user_id)], Ok)
  |> result.map(fn(_) { Nil })
}

fn decoder(data: Dynamic) {
  data
  |> dynamic.decode3(
    User,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.int),
  )
}
