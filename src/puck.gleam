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
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
    ["server"] -> server(config)
    ["email"] -> email(config)
    ["attendee"] -> append_attendee(config)
    _ -> unknown()
  }
}

fn unknown() {
  io.println(usage)
  halt(1)
}

fn server(config: Config) {
  install_log_handler(error_email(_, config))

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

fn email(config: Config) {
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
      subject: "Hello, Joe!",
      content: "System still-still working?",
    )

  assert Ok(_) = gen_smtp.send(email, options)
  Nil
}

fn error_email(error: String, config: Config) {
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

fn append_attendee(config) {
  let attendee =
    attendee.Attendee(
      name: "Lou",
      email: "louis@lpil.uk",
      attended: True,
      pal: "Al",
      pal_attended: False,
      diet: "fud",
      accessibility: "nothing",
      contribution: attendee.RolloverTicket,
      reference: attendee.generate_reference(),
    )

  assert Ok(_) = sheets.append_attendee(attendee, config)
  Nil
}
