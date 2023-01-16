import puck/payment.{Payment}
import puck/attendee
import puck/sheets
import puck/expiring_set
import puck/config.{Config}
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/database
import puck/web/templates.{Templates}
import gleam/option
import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/process
import gleam/bit_string
import gleam/string
import gleam/uri
import gleam/io

pub type State {
  State(templates: Templates, db: database.Connection, config: Config)
}

pub fn service(config: Config) -> Service(BitString, BitBuilder) {
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
    ["api", "payment", key] if key == pay -> payments(request, state.config)
    _ -> not_found()
  }
}

fn attendance(request: Request(BitString), state: State) {
  case request.method {
    http.Get -> attendance_form(state)
    http.Post -> register_attendance(request, state)
    _ -> method_not_allowed()
  }
}

fn attendance_form(state: State) {
  let html = state.templates.home(state.config.help_email)
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn register_attendance(request: Request(BitString), state: State) {
  use params <- decode_form_urlencoded_body(request)
  use attendee <- require_ok(attendee.from_query(params))

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

fn not_found() {
  response.new(404)
  |> response.set_body("There's nothing here...")
}

fn payments(request: Request(BitString), config: Config) {
  use body <- decode_bit_string_body(request)
  use payment <- require_ok(payment.from_json(body))

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

fn method_not_allowed() -> Response(String) {
  response.new(405)
  |> response.set_body("Method not allowed")
}

fn unprocessable_entity() -> Response(String) {
  response.new(422)
  |> response.set_body(
    "Unprocessable entity. Please try again and contact the organisers if the problem continues",
  )
}

fn bad_request() -> Response(String) {
  response.new(400)
  |> response.set_body(
    "Invalid request. Please try again and contact the organisers if the problem continues",
  )
}

fn decode_bit_string_body(
  request: Request(BitString),
  next: fn(String) -> Response(String),
) -> Response(String) {
  case bit_string.to_string(request.body) {
    Ok(body) -> next(body)
    Error(_) -> bad_request()
  }
}

fn decode_form_urlencoded_body(
  request: Request(BitString),
  next: fn(List(#(String, String))) -> Response(String),
) -> Response(String) {
  use body <- decode_bit_string_body(request)
  case uri.parse_query(body) {
    Ok(body) -> next(body)
    Error(_) -> unprocessable_entity()
  }
}

fn require_ok(
  result: Result(a, b),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> unprocessable_entity()
  }
}
