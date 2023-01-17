import sqlight
import puck/error.{Error}
import puck/attendee
import puck/database
import gleam/dynamic.{Dynamic}
import gleam/option.{Option}

pub type User {
  User(id: Int, email: String, interactions: Int)
}

pub type Application {
  Application(id: Int, payment_reference: String, user_id: Int)
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

pub fn get_or_insert_application(
  conn: database.Connection,
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
      payment_reference = $1
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
      id = $1
    returning
      id, email, interactions
    "
  let arguments = [sqlight.int(user_id)]
  database.maybe_one(sql, conn, arguments, decoder)
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
