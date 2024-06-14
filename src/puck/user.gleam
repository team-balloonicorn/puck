import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic} as dy
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import puck/database
import puck/error.{type Error}
import sqlight

pub type User {
  User(
    id: Int,
    name: String,
    email: String,
    interactions: Int,
    is_admin: Bool,
    payment_reference: String,
    answers: Dict(String, String),
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
      (name, email, payment_reference) 
    values
      (?1, ?2, ?3)
    returning
      id, name, email, interactions, is_admin, payment_reference, answers
    "
  let arguments = [
    sqlight.text(name),
    sqlight.text(string.lowercase(email)),
    sqlight.text(generate_reference()),
  ]

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
      id, name, email, interactions, is_admin, payment_reference, answers
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
      id, name, email, interactions, is_admin, payment_reference, answers
    from
      users
    where
      email = ?1
    "
  database.maybe_one(
    sql,
    conn,
    [sqlight.text(string.lowercase(email))],
    decoder,
  )
}

/// Insert the application for a user. If the user already has an application then
/// the answers are merged into the existing record.
pub fn record_answers(
  conn: database.Connection,
  user_id user_id: Int,
  answers answers: Dict(String, String),
) -> Result(Nil, Error) {
  let sql =
    "
    update users set
      answers = json_patch(answers, ?2)
    where
      id = ?1
    "
  let json =
    json.to_string(json.object(
      answers
      |> dict.map_values(fn(_, v) { json.string(v) })
      |> dict.to_list,
    ))
  let arguments = [sqlight.int(user_id), sqlight.text(json)]
  use _ <- result.try(database.query(sql, conn, arguments, Ok))
  Ok(Nil)
}

pub fn get_user_by_payment_reference(
  conn: database.Connection,
  reference: String,
) -> Result(Option(User), Error) {
  let sql =
    "
    select
      users.id, name, email, interactions, is_admin, payment_reference, answers
    from
      users
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
      id, name, email, interactions, is_admin, payment_reference, answers
    "
  let arguments = [sqlight.int(user_id)]
  database.maybe_one(sql, conn, arguments, decoder)
}

/// Get a login token for a user, creating and storing a new one if there is not
/// one in the database that has not expired.
///
/// Resets the timer on the token in the database if it is fresh.
///
pub fn get_or_create_login_token(
  conn: database.Connection,
  user_id: Int,
) -> Result(Option(String), Error) {
  let token = case get_login_token(conn, user_id) {
    Ok(option.Some(token)) -> token
    _ -> bit_array.base64_url_encode(crypto.strong_random_bytes(24), False)
  }
  let sql =
    "
    update users set 
      login_token = ?2,
      login_token_created_at = datetime('now')
    where
      id = ?1
    returning
      id
    "
  let arguments = [sqlight.int(user_id), sqlight.text(token)]
  use row <- result.try(database.maybe_one(sql, conn, arguments, Ok))
  row
  |> option.map(fn(_) { token })
  |> Ok
}

pub fn get_login_token(
  conn: database.Connection,
  user_id: Int,
) -> Result(Option(String), Error) {
  let sql =
    "
    select
      login_token
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
  |> dy.decode7(
    User,
    dy.element(0, dy.int),
    dy.element(1, dy.string),
    dy.element(2, dy.string),
    dy.element(3, dy.int),
    dy.element(4, sqlight.decode_bool),
    dy.element(5, dy.string),
    dy.element(6, json_object(dy.string)),
  )
}

fn json_object(inner: dy.Decoder(t)) -> dy.Decoder(Dict(String, t)) {
  fn(data: Dynamic) {
    use string <- result.then(dy.string(data))
    json.decode(string, using: dy.dict(dy.string, inner))
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
  |> bit_array.base64_url_encode(False)
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
  |> bit_array.from_string
  |> bit_array.slice(0, 12)
  // Convert it back to a string. This should never fail.
  |> result.then(bit_array.to_string)
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
