import puck/web/routes
import puck/email
import puck/database
import puck/config.{Config}
import gleam/io
import gleam/erlang
import gleam/erlang/process
import mist

const usage = "USAGE:
  puck server
  puck email-everyone
  puck get-attendee-email <reference>
  puck send-attendance-email <email> <amount> <reference>
  puck send-payment-confirmation-email <email> <paid_in_pence>
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
    ["server"] -> server(config)
    ["email-everyone"] -> email_everyone(config)
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

/// Comment out the code to send an email to everyone
fn email_everyone(_config: Config) -> Nil {
  // let subject = ""
  // let content = ""
  //
  // assert Ok(token) = sheets.get_access_token(config)
  // assert Ok(emails) = sheets.all_attendee_emails(token, config)
  //
  // emails
  // |> set.to_list
  // |> list.each(fn(to) {
  //   io.println(to)
  //   assert Ok(_) =
  //     gen_smtp.Email(
  //       content: content,
  //       to: [to],
  //       from_email: config.smtp_from_email,
  //       from_name: config.smtp_from_name,
  //       subject: subject,
  //     )
  //     |> email.send(config)
  //   Nil
  // })
  Nil
}
