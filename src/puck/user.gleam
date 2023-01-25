import bcrypter
import gleam/base
import gleam/crypto
import gleam/dynamic.{Dynamic} as dy
import gleam/map.{Map}
import gleam/option.{Option}
import gleam/result
import gleam/json
import puck/attendee
import puck/database
import puck/error.{Error}
import sqlight

pub type User {
  User(id: Int, email: String, interactions: Int)
}

pub type Application {
  Application(
    id: Int,
    payment_reference: String,
    user_id: Int,
    answers: Map(String, String),
  )
}

pub fn get_or_insert_by_email(
  conn: database.Connection,
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

pub fn get_by_email(
  conn: database.Connection,
  email: String,
) -> Result(Option(User), Error) {
  let sql =
    "
    select 
      id, email, interactions
    from
      users
    where
      email = ?1
    "
  database.maybe_one(sql, conn, [sqlight.text(email)], decoder)
}

/// Insert the application for a user. If the user already has an application then
/// the answers are merged into the existing record.
pub fn insert_application(
  conn: database.Connection,
  user_id user_id: Int,
  answers answers: Map(String, String),
) -> Result(Application, Error) {
  let sql =
    "
    insert into applications 
      (user_id, payment_reference, answers)
    values
      (?1, ?2, ?3)
    on conflict (user_id) do
      update set answers = json_patch(answers, excluded.answers)
    returning
      id, payment_reference, user_id, answers
    "
  let json =
    json.to_string(json.object(
      answers
      |> map.map_values(fn(_, v) { json.string(v) })
      |> map.to_list,
    ))
  let arguments = [
    sqlight.int(user_id),
    sqlight.text(attendee.generate_reference()),
    sqlight.text(json),
  ]
  database.one(sql, conn, arguments, application_decoder)
}

/// Get the application for a user.
pub fn get_application(
  conn: database.Connection,
  user_id: Int,
) -> Result(Option(Application), Error) {
  let sql =
    "
    select
      id, payment_reference, user_id, answers
    from
      applications 
    where
      user_id = ?1
    "
  let arguments = [sqlight.int(user_id)]
  database.maybe_one(sql, conn, arguments, application_decoder)
}

pub fn get_user_by_payment_reference(
  conn: database.Connection,
  reference: String,
) -> Result(Option(User), Error) {
  let sql =
    "
    select
      users.id, email, interactions
    from
      users
    join
      applications on users.id = applications.user_id
    where
      payment_reference = ?1
    "
  let arguments = [sqlight.text(reference)]
  database.maybe_one(sql, conn, arguments, decoder)
}

pub fn get_and_increment_interaction(
  conn: database.Connection,
  user_id: Int,
) -> Result(Option(User), Error) {
  let sql =
    "
    update users set 
      interactions = interactions + 1
    where
      id = ?1
    returning
      id, email, interactions
    "
  let arguments = [sqlight.int(user_id)]
  database.maybe_one(sql, conn, arguments, decoder)
}

/// Create a login token for a user, storing the hash in the database.
///
pub fn create_login_token(
  conn: database.Connection,
  user_id: Int,
) -> Result(Option(String), Error) {
  let token =
    crypto.strong_random_bytes(24)
    |> base.url_encode64(False)
  let hash = bcrypter.hash(token)
  let sql =
    "
    update users set 
      login_token_hash = ?2
    where
      id = ?1
    returning
      id
    "
  let arguments = [sqlight.int(user_id), sqlight.text(hash)]
  use row <- result.then(database.maybe_one(sql, conn, arguments, Ok))
  row
  |> option.map(fn(_) { token })
  |> Ok
}

/// Set the login token hash for a user to null.
///
/// Returns `True` if the user exists, `False` otherwise.
///
pub fn delete_login_token_hash(
  conn: database.Connection,
  user_id: Int,
) -> Result(Bool, Error) {
  let sql =
    "
    update users set 
      login_token_hash = null
    where
      id = ?1
    returning
      id
    "
  let arguments = [sqlight.int(user_id)]
  database.maybe_one(sql, conn, arguments, Ok)
  |> result.map(option.is_some)
}

pub fn get_login_token_hash(
  conn: database.Connection,
  user_id: Int,
) -> Result(Option(String), Error) {
  let sql =
    "
    select
      login_token_hash
    from
      users
    where
      id = ?1
    "
  let arguments = [sqlight.int(user_id)]
  let decoder = dy.element(0, dy.optional(dy.string))
  database.maybe_one(sql, conn, arguments, decoder)
  |> result.map(option.flatten)
}

fn decoder(data: Dynamic) {
  data
  |> dy.decode3(
    User,
    dy.element(0, dy.int),
    dy.element(1, dy.string),
    dy.element(2, dy.int),
  )
}

fn application_decoder(data: Dynamic) {
  data
  |> dy.decode4(
    Application,
    dy.element(0, dy.int),
    dy.element(1, dy.string),
    dy.element(2, dy.int),
    dy.element(3, json_object(dy.string)),
  )
}

fn json_object(inner: dy.Decoder(t)) -> dy.Decoder(Map(String, t)) {
  fn(data: Dynamic) {
    use string <- result.then(dy.string(data))
    json.decode(string, using: dy.map(dy.string, inner))
    |> result.map_error(fn(error) {
      case error {
        json.UnexpectedFormat(errors) -> errors
        _ -> [dy.DecodeError(expected: "Json", found: "String", path: [])]
      }
    })
  }
}
