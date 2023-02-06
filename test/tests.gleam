import gleam/int
import gleam/option.{None, Some}
import gleam/http/request.{Request}
import gleam/erlang/process.{Subject}
import puck/config.{Config}
import puck/database
import puck/user
import puck/email.{Email}
import puck/web.{State}
import puck/web/templates
import sqlight

/// Open a unique in-memory database connection.
pub fn with_connection(f: fn(sqlight.Connection) -> a) -> a {
  use db <- database.with_connection("")
  database.migrate(db)
  f(db)
}

pub fn config() -> Config {
  let random = fn() { int.to_string(int.random(0, 1_000_000)) }
  Config(
    environment: random(),
    database_path: random(),
    help_email: random(),
    signing_secret: random(),
    payment_secret: random(),
    pushover_user: random(),
    pushover_key: random(),
    attend_secret: "attendance-secret" <> random(),
    reload_templates: False,
    zeptomail_api_key: random(),
    email_from_address: random(),
    email_from_name: random(),
    email_replyto_address: random(),
    email_replyto_name: random(),
    account_name: random(),
    account_number: random(),
    sort_code: random(),
  )
}

pub fn with_state(f: fn(State) -> a) -> a {
  let config = config()
  use db <- database.with_connection("")
  database.migrate(db)
  let state =
    State(
      db: db,
      config: config,
      current_user: None,
      send_email: fn(_) { Nil },
      send_admin_notification: fn(_, _) { Nil },
      templates: templates.load(config),
    )
  f(state)
}

pub fn with_logged_in_state(f: fn(State) -> a) -> a {
  use state <- with_state
  assert Ok(user) = user.insert(state.db, "Puck", "puck@example.com")
  let state = State(..state, current_user: Some(user))
  f(state)
}

pub fn request(path: String) -> Request(BitString) {
  request.new()
  |> request.set_path(path)
  |> request.set_body(<<>>)
}

pub fn track_sent_notifications(
  state: State,
) -> #(State, Subject(#(String, String))) {
  let subject = process.new_subject()
  let send = fn(title, message) { process.send(subject, #(title, message)) }
  let state = State(..state, send_admin_notification: send)
  #(state, subject)
}

pub fn track_sent_emails(state: State) -> #(State, Subject(Email)) {
  let subject = process.new_subject()
  let send_email = fn(email) { process.send(subject, email) }
  let state = State(..state, send_email: send_email)
  #(state, subject)
}
