import argv
import gleam/erlang
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/string
import mist
import puck/config.{type Config}
import puck/database
import puck/email
import puck/pushover
import puck/routes
import puck/user
import puck/web.{type Context, Context}
import puck/web/auth
import puck/web/templates
import simplifile
import wisp

const usage = "USAGE:
  puck server
  puck email <subject> <body.txt> <addresses.txt>
  puck login-url <user_id>
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case argv.load().arguments {
    ["server"] -> server(config)
    ["login-url", user_id] -> login_url(user_id, config)
    ["email", subject, body, addresses] ->
      email(subject, body, addresses, config)
    _ -> unknown()
  }
}

fn unknown() {
  io.println(usage)
  halt(1)
}

fn server(config: Config) {
  case config.environment {
    "development" -> Nil
    _ -> install_log_handler(send_error_email(_, config))
  }
  database.with_connection(config.database_path, database.migrate)

  let handle_request = fn(req) {
    use db <- database.with_connection(config.database_path)
    use user <- auth.get_user_from_session(req, db, config.signing_secret)
    let ctx =
      Context(
        config: config,
        db: db,
        templates: templates.load(config),
        current_user: user,
        send_email: email.send(_, config),
        send_admin_notification: fn(title, message) {
          let assert Ok(_) = pushover.notify(config, title, message)
          Nil
        },
      )
    routes.handle_request(req, ctx)
  }

  // Start the web server process
  let assert Ok(_) =
    wisp.mist_handler(handle_request, config.signing_secret)
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  // Put the main process to sleep while the web server does its thing
  process.sleep_forever()
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

@external(erlang, "puck_log_handler", "install")
fn install_log_handler(formatter: fn(String) -> Nil) -> Nil

fn send_error_email(error: String, config: Config) {
  email.Email(
    to_name: config.email_replyto_name,
    to_address: config.email_replyto_address,
    subject: "Website error occurred!",
    content: error,
  )
  |> email.send(config)

  Nil
}

fn email(
  subject: String,
  body: String,
  addresses: String,
  config: Config,
) -> Nil {
  let assert Ok(addresses) = simplifile.read(addresses)
  let assert Ok(body) = simplifile.read(body)
  let addresses = string.split(string.trim(addresses), "\n")

  list.each(addresses, io.println)
  use <- ask_confirmation("Do these emails look right?")

  io.println(subject)
  use <- ask_confirmation("Does this subject look right?")

  io.println(body)
  use <- ask_confirmation("Does this body look right?")

  use address <- list.each(addresses)
  io.println("Sending: " <> address)

  email.Email(
    to_name: address,
    to_address: address,
    subject: subject,
    content: body,
  )
  |> email.send(config)
  process.sleep(200)
}

fn ask_confirmation(prompt: String, next: fn() -> Nil) -> Nil {
  let input = erlang.get_line(">>> " <> prompt <> " (y/N) ")
  case input {
    Ok("y\n") -> next()
    _ -> io.println("Cancelled. Bye!")
  }
}

fn login_url(user_id: String, config: Config) -> Nil {
  use db <- database.with_connection(config.database_path)
  let assert Ok(id) = int.parse(user_id)
  let assert Ok(Some(token)) = user.get_or_create_login_token(db, id)
  io.println("https://puck.midsummer.lpil.uk/login/" <> user_id <> "/" <> token)
}
