import puck/web
import puck/sheets
import puck/attendee
import puck/config.{Config}
import gleam/io
import gleam/erlang
import gleam/http/elli
import gleam/gen_smtp

const usage = "USAGE:
  puck server
  puck attendee-email <reference>
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
    ["server"] -> server(config)
    ["attendee-email", reference] -> get_attendee_email(reference, config)
    _ -> unknown()
  }
}

fn unknown() {
  io.println(usage)
  halt(1)
}

fn server(config: Config) {
  install_log_handler(send_error_email(_, config))

  // Refreshing the Google Sheets access token in the background
  assert Ok(_) = sheets.start_refresher(config)

  // Start the web server process
  assert Ok(_) = elli.start(web.service(config), on_port: 3000)
  io.println("Started listening on localhost:3000 ✨")

  // Put the main process to sleep while the web server does its thing
  erlang.sleep_forever()
}

external fn halt(Int) -> Nil =
  "erlang" "halt"

external fn install_log_handler(fn(String) -> Nil) -> Nil =
  "puck_log_handler" "install"

fn send_error_email(error: String, config: Config) {
  let options =
    gen_smtp.Options(
      relay: config.smtp_host,
      port: config.smtp_port,
      username: config.smtp_username,
      password: config.smtp_password,
      auth: gen_smtp.Always,
      ssl: True,
      retries: 2,
    )

  let email =
    gen_smtp.Email(
      from_email: config.smtp_from_email,
      from_name: config.smtp_from_name,
      to: ["louispilfold@gmail.com"],
      subject: "Puck error occurred!",
      content: error,
    )

  assert Ok(_) = gen_smtp.send(email, options)
  Nil
}

fn get_attendee_email(reference: String, config: Config) -> Nil {
  assert Ok(attendee) = sheets.get_attendee_email(reference, config)
  io.debug(attendee)
  Nil
}
