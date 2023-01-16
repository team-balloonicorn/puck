import sqlight
import puck/error.{Error}
import puck/attendee
import puck/database
import gleam/dynamic.{Dynamic}
import gleam/result

pub type User {
  User(id: Int, email: String, interactions: Int)
}

pub type Application {
  Application(id: Int, payment_reference: String, user_id: Int)
}

pub fn get_or_insert_by_email(
  conn: sqlight.Connection,
  email: String,
) -> Result(User, Error) {
  let sql =
    "
    insert into users
      (email) 
    values
      (?)
    on conflict (email) do 
      update set email = email
    returning
      id, email, interactions
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

pub fn get_or_insert_application(
  conn: sqlight.Connection,
  user_id: Int,
) -> Result(Application, Error) {
  let sql =
    "
    insert into applications 
      (user_id, payment_reference) 
    values
      ($1, $2)
    on conflict (user_id) do
      update set user_id = user_id
    returning
      id, payment_reference, user_id
    "
  let arguments = [
    sqlight.int(user_id),
    sqlight.text(attendee.generate_reference()),
  ]
  database.one(sql, conn, arguments, application_decoder)
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

fn application_decoder(data: Dynamic) {
  data
  |> dynamic.decode3(
    Application,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.int),
  )
}
