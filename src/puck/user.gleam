import sqlight
import puck/error.{Error}
import gleam/dynamic.{Dynamic}
import gleam/result.{then}

pub type User {
  User(id: Int, email: String, interactions: Int)
}

pub fn get_or_insert_by_email(
  connection: sqlight.Connection,
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
  use users <- then(
    sqlight.query(sql, connection, [sqlight.text(email)], decoder)
    |> result.map_error(error.SqlightError),
  )
  assert [user] = users
  Ok(user)
}

pub fn increment_interaction_count(
  connection: sqlight.Connection,
  user_id: Int,
) -> Result(Nil, Error) {
  let sql =
    "
    update users
    set interactions = interactions + 1
    where id = ?
    "
  use _ <- then(
    sqlight.query(sql, connection, [sqlight.int(user_id)], Ok)
    |> result.map_error(error.SqlightError),
  )
  Ok(Nil)
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
