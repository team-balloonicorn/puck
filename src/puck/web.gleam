import puck/payment.{Payment}
import puck/attendee
import puck/sheets
import puck/expiring_set
import puck/config.{Config}
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/web/templates.{Templates}
import gleam/option
import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/otp/process
import gleam/bit_string
import gleam/result
import gleam/string
import gleam/json
import gleam/uri
import gleam/io

pub type State {
  State(templates: Templates, config: Config)
}

pub fn service(config: Config) -> Service(BitString, BitBuilder) {
  let state = State(config: config, templates: templates.load(config))

  router(_, state)
  |> service.map_response_body(bit_builder.from_string)
  |> print_requests.middleware
  |> static.middleware
  |> service.prepend_response_header("made-with", "Gleam")
  |> service.prepend_response_header("x-robots-tag", "noindex")
  |> rescue_errors.middleware
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
  |> result.map_error(error_to_response)
  |> unwrap_both
}

fn attendance(request: Request(BitString), state: State) {
  case request.method {
    http.Get -> attendance_form(state)
    http.Post -> register_attendance(request, state)
    _ -> Error(HttpMethodNotAllowed)
  }
}

fn attendance_form(state: State) {
  let html = state.templates.home(state.config.help_email)
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
  |> Ok
}

fn register_attendance(request: Request(BitString), state: State) {
  try params = form_urlencoded_body(request)
  try attendee =
    attendee.from_query(params)
    |> result.replace_error(InvalidParameters)

  // Record the new attendee in the database
  assert Ok(_) = sheets.append_attendee(attendee, state.config)

  // Send a confirmation email to the attendee
  process.start_unlinked(fn() {
    attendee.send_attendance_email(
      attendee.reference,
      attendee.name,
      attendee.email,
      state.config,
    )
  })

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
  |> Ok
}

fn licence(state: State) {
  let html = state.templates.licence()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
  |> Ok
}

fn pal_system(state: State) {
  let html = state.templates.pal_system()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
  |> Ok
}

fn not_found() {
  response.new(404)
  |> response.set_body("There's nothing here...")
  |> Ok
}

type Error {
  UnexpectedJson(String, json.DecodeError)
  HttpMethodNotAllowed
  InvalidParameters
  InvalidFormUrlencoded
  InvalidUtf8
}

fn payments(request: Request(BitString), config: Config) {
  try json =
    bit_string.to_string(request.body)
    |> result.replace_error(InvalidUtf8)

  try payment =
    payment.from_json(json)
    |> result.map_error(UnexpectedJson(json, _))

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

  Ok(response.new(200))
}

fn record_new_payment(
  payment: Payment,
  config: Config,
) -> Result(Nil, sheets.Error) {
  // Record the payment in Google sheets
  try _ = sheets.append_payment(payment, config)

  // In the background send check if the payment if for an attendee and send
  // them a confirmation email if so
  process.start_unlinked(fn() {
    assert Ok(attendee) = sheets.get_attendee_email(payment.reference, config)
    option.map(
      attendee,
      attendee.send_payment_confirmation_email(payment.amount, _, config),
    )
    Nil
  })

  Ok(Nil)
}

fn unwrap_both(result: Result(a, a)) -> a {
  case result {
    Ok(value) -> value
    Error(value) -> value
  }
}

fn error_to_response(error: Error) -> Response(String) {
  case error {
    HttpMethodNotAllowed -> response.new(405)
    InvalidUtf8 | InvalidFormUrlencoded -> response.new(400)
    InvalidParameters ->
      response.new(422)
      |> response.set_body(
        "Unprocessable entity. Please try again and contact the organisers if the problem continues",
      )

    UnexpectedJson(_, _) -> {
      // Crash to get the error reported via email
      throw(error)
      response.new(400)
    }
  }
}

external fn throw(anything) -> Nil =
  "erlang" "throw"

fn form_urlencoded_body(
  request: Request(BitString),
) -> Result(List(#(String, String)), Error) {
  try body =
    bit_string.to_string(request.body)
    |> result.replace_error(InvalidUtf8)
  uri.parse_query(body)
  |> result.replace_error(InvalidFormUrlencoded)
}
