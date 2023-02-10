import bcrypter
import gleam/base
import gleam/crypto
import gleam/dynamic.{Dynamic} as dy
import gleam/map.{Map}
import gleam/option.{Option}
import gleam/result
import gleam/json
import puck/database
import puck/error.{Error}
import sqlight
import gleam/string
import gleam/bit_string

pub type User {
  User(id: Int, name: String, email: String, interactions: Int, is_admin: Bool)
}

pub type Application {
  Application(
    id: Int,
    payment_reference: String,
    user_id: Int,
    answers: Map(String, String),
  )
}

pub fn insert(
  conn: database.Connection,
  name name: String,
  email email: String,
) -> Result(User, Error) {
  let sql =
    "
    insert into users
      (name, email) 
    values
      (?1, ?2)
    returning
      id, name, email, interactions, is_admin
    "
  let arguments = [sqlight.text(name), sqlight.text(email)]

  case database.one(sql, conn, arguments, decoder) {
    Ok(user) -> Ok(user)
    Error(error.Database(sqlight.SqlightError(
      sqlight.ConstraintUnique,
      "UNIQUE constraint failed: users.email",
      _,
    ))) -> Error(error.EmailAlreadyInUse)
    Error(err) -> Error(err)
  }
}

pub fn list_all(conn: database.Connection) -> Result(List(User), Error) {
  let sql =
    "
    select
      id, name, email, interactions, is_admin
    from users
    limit 1000
    "

  database.query(sql, conn, [], decoder)
}

pub fn get_by_email(
  conn: database.Connection,
  email: String,
) -> Result(Option(User), Error) {
  let sql =
    "
    select 
      id, name, email, interactions, is_admin
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
    sqlight.text(generate_reference()),
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
      users.id, name, email, interactions, is_admin
    from
      users
    join
      applications on users.id = applications.user_id
    where
      payment_reference = ?1
    "
  let arguments = [sqlight.text(string.uppercase(reference))]
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
      id, name, email, interactions, is_admin
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
      login_token_hash = ?2,
      login_token_created_at = datetime('now')
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
    and
      login_token_created_at > datetime('now', '-1 day')
    "
  let arguments = [sqlight.int(user_id)]
  let decoder = dy.element(0, dy.optional(dy.string))
  database.maybe_one(sql, conn, arguments, decoder)
  |> result.map(option.flatten)
}

fn decoder(data: Dynamic) {
  data
  |> dy.decode5(
    User,
    dy.element(0, dy.int),
    dy.element(1, dy.string),
    dy.element(2, dy.string),
    dy.element(3, dy.int),
    dy.element(4, sqlight.decode_bool),
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

fn generate_reference() -> String {
  // Generate random string
  crypto.strong_random_bytes(50)
  |> base.url_encode64(False)
  |> string.lowercase
  // Remove ambiguous characters
  |> string.replace("o", "")
  |> string.replace("O", "")
  |> string.replace("0", "")
  |> string.replace("1", "")
  |> string.replace("i", "")
  |> string.replace("l", "")
  |> string.replace("_", "")
  |> string.replace("-", "")
  // Slice it down to a desired size
  |> bit_string.from_string
  |> bit_string.slice(0, 12)
  // Convert it back to a string. This should never fail.
  |> result.then(bit_string.to_string)
  |> result.map(string.append("m-", _))
  // Try again it if fails. It never should.
  |> result.lazy_unwrap(fn() { generate_reference() })
}

// TODO: test
pub fn count_users_with_payments(
  conn: database.Connection,
) -> Result(Int, Error) {
  let sql =
    "
    select
      count(distinct users.id)
    from
      users
    join
      applications on users.id = applications.user_id
    join
      payments on payments.reference = applications.payment_reference
    where
      applications.id is not null
    "
  let arguments = []
  database.one(sql, conn, arguments, dy.element(0, dy.int))
}
