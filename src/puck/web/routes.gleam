import bcrypter
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/process
import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/int
import gleam/io
import gleam/option
import gleam/string
import puck/attendee
import puck/config.{Config}
import puck/database
import puck/expiring_set
import puck/payment.{Payment}
import puck/sheets
import puck/user
import puck/web.{State}
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/web/templates

pub fn service(config: Config) {
  handle_request(_, config)
}

pub fn handle_request(
  request: Request(BitString),
  config: Config,
) -> Response(BitBuilder) {
  use <- rescue_errors.middleware
  use <- static.serve_assets(request)
  use <- print_requests.middleware(request)

  use db <- database.with_connection(config.database_path)
  let state = State(config: config, db: db, templates: templates.load(config))

  router(request, state)
  |> response.prepend_header("x-robots-tag", "noindex")
  |> response.prepend_header("made-with", "Gleam")
  |> response.map(bit_builder.from_string)
}

fn router(request: Request(BitString), state: State) -> Response(String) {
  let pay = state.config.payment_secret
  let attend = state.config.attend_secret

  case request.path_segments(request) {
    [key] if key == attend -> attendance(request, state)
    ["licence"] -> licence(state)
    ["the-pal-system"] -> pal_system(state)
    ["login", user_id, token] -> login(user_id, token, state)
    ["api", "payment", key] if key == pay -> payments(request, state.config)
    _ -> web.not_found()
  }
}

// TODO: test
fn login(user_id: String, token: String, state: State) {
  use user_id <- web.ok(int.parse(user_id))
  use hash <- web.ok_or_404(user.get_login_token_hash(state.db, user_id))
  use hash <- web.some(hash)
  case bcrypter.verify(token, hash) {
    True -> {
      assert Ok(_) = user.delete_login_token_hash(state.db, user_id)
      web.redirect("/admin")
      |> web.set_signed_user_id_cookie(user_id, state.config.signing_secret)
    }
    False -> web.not_found()
  }
}

fn attendance(request: Request(BitString), state: State) {
  case request.method {
    http.Get -> attendance_form(state)
    http.Post -> register_attendance(request, state)
    _ -> web.method_not_allowed()
  }
}

fn attendance_form(state: State) {
  let html = state.templates.home(state.config.help_email)
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn register_attendance(request: Request(BitString), state: State) {
  use params <- web.require_form_urlencoded_body(request)
  use attendee <- web.ok(attendee.from_query(params))

  // TODO: record in database
  // Record the new attendee in the database
  assert Ok(_) = sheets.append_attendee(attendee, state.config)

  // TODO: check this succeeds
  // Send a confirmation email to the attendee
  process.start(
    fn() {
      attendee.send_attendance_email(
        attendee.reference,
        attendee.name,
        attendee.email,
        state.config,
      )
    },
    linked: False,
  )

  let html =
    state.templates.submitted(templates.Submitted(
      help_email: state.config.help_email,
      account_name: state.config.account_name,
      account_number: state.config.account_number,
      sort_code: state.config.sort_code,
      reference: attendee.reference,
    ))

  response.new(201)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn licence(state: State) {
  let html = state.templates.licence()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn pal_system(state: State) {
  let html = state.templates.pal_system()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn payments(request: Request(BitString), config: Config) {
  use body <- web.require_bit_string_body(request)
  use payment <- web.ok(payment.from_json(body))

  let tx_key = string.append(payment.created_at, payment.reference)
  assert Ok(_) = case
    expiring_set.register_new(config.transaction_set, tx_key)
  {
    True -> record_new_payment(payment, config)
    False -> {
      io.println(string.append("Discarding duplicate transaction ", tx_key))
      Ok(Nil)
    }
  }
  response.new(200)
}

fn record_new_payment(
  payment: Payment,
  config: Config,
) -> Result(Nil, sheets.Error) {
  // Record the payment in Google sheets
  try _ = sheets.append_payment(payment, config)

  // In the background send check if the payment if for an attendee and send
  // them a confirmation email if so
  process.start(
    fn() {
      assert Ok(attendee) = sheets.get_attendee_email(payment.reference, config)
      option.map(
        attendee,
        attendee.send_payment_confirmation_email(payment.amount, _, config),
      )
      Nil
    },
    linked: False,
  )

  Ok(Nil)
}
