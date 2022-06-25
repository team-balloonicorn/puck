import puck/web
import puck/email
import puck/sheets
import puck/attendee
import puck/config.{Config}
import gleam/io
import gleam/int
import gleam/erlang
import gleam/http/elli
import gleam/gen_smtp

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
    ["get-attendee-email", reference] -> get_attendee_email(reference, config)
    ["send-attendance-email", email, reference] ->
      send_attendance_email(email, reference, config)
    ["send-payment-confirmation-email", email, amount] ->
      send_payment_confirmation_email(email, amount, config)
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
  assert Ok(_) =
    gen_smtp.Email(
      from_email: config.smtp_from_email,
      from_name: config.smtp_from_name,
      to: ["louispilfold@gmail.com"],
      subject: "Puck error occurred!",
      content: error,
    )
    |> email.send(config)

  Nil
}

fn get_attendee_email(reference: String, config: Config) -> Nil {
  assert Ok(attendee) = sheets.get_attendee_email(reference, config)
  io.debug(attendee)
  Nil
}

fn send_attendance_email(
  email: String,
  reference: String,
  config: Config,
) -> Nil {
  assert Ok(_) = attendee.send_attendance_email(reference, email, config)
  Nil
}

fn send_payment_confirmation_email(
  email: String,
  amount: String,
  config: Config,
) -> Nil {
  assert Ok(amount) = int.parse(amount)
  assert Ok(_) = attendee.send_payment_confirmation_email(amount, email, config)
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
