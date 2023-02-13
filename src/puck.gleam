import puck/web/routes
import puck/email
import puck/user
import puck/database
import puck/config.{Config}
import gleam/io
import gleam/int
import gleam/option.{Some}
import gleam/erlang
import gleam/erlang/process
import gleam/erlang/file
import gleam/list
import gleam/string
import mist

const usage = "USAGE:
  puck server
  puck email <subject> <body.txt> <addresses.txt>
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
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

  // Start the web server process
  assert Ok(_) =
    mist.run_service(3000, routes.service(config), max_body_limit: 4_000_000)
  io.println("Started listening on http://localhost:3000 ✨")

  // Put the main process to sleep while the web server does its thing
  process.sleep_forever()
}

external fn halt(Int) -> Nil =
  "erlang" "halt"

external fn install_log_handler(fn(String) -> Nil) -> Nil =
  "puck_log_handler" "install"

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
  assert Ok(addresses) = file.read(addresses)
  assert Ok(body) = file.read(body)
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
  assert Ok(id) = int.parse(user_id)
  assert Ok(Some(token)) = user.create_login_token(db, id)
  io.println("https://puck.midsummer.lpil.uk/login/" <> user_id <> "/" <> token)
}
