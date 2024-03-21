import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/option.{None, Some}
import puck/config.{type Config, Config}
import puck/database
import puck/email.{type Email}
import puck/user
import puck/web.{type Context, Context}
import puck/web/templates
import sqlight

/// Open a unique in-memory database connection.
pub fn with_connection(f: fn(sqlight.Connection) -> a) -> a {
  use db <- database.with_connection("")
  database.migrate(db)
  f(db)
}

pub fn config() -> Config {
  let random = fn() { int.to_string(int.random(1_000_000)) }
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

pub fn with_context(f: fn(Context) -> a) -> a {
  let config = config()
  use db <- database.with_connection("")
  database.migrate(db)
  let ctx =
    Context(
      db: db,
      config: config,
      current_user: None,
      send_email: fn(_) { Nil },
      send_admin_notification: fn(_, _) { Nil },
      templates: templates.load(config),
    )
  f(ctx)
}

pub fn with_logged_in_context(f: fn(Context) -> a) -> a {
  use ctx <- with_context
  let assert Ok(user) = user.insert(ctx.db, "Puck", "puck@example.com")
  let ctx = Context(..ctx, current_user: Some(user))
  f(ctx)
}

pub fn track_sent_notifications(
  ctx: Context,
) -> #(Context, Subject(#(String, String))) {
  let subject = process.new_subject()
  let send = fn(title, message) { process.send(subject, #(title, message)) }
  let ctx = Context(..ctx, send_admin_notification: send)
  #(ctx, subject)
}

pub fn track_sent_emails(ctx: Context) -> #(Context, Subject(Email)) {
  let subject = process.new_subject()
  let send_email = fn(email) { process.send(subject, email) }
  let ctx = Context(..ctx, send_email: send_email)
  #(ctx, subject)
}
