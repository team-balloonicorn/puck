import gleam/bit_builder.{BitBuilder}
import gleam/erlang/process
import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import puck/attendee
import puck/config.{Config}
import puck/database
import puck/payment
import puck/email
import puck/web.{State}
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/web/templates
import puck/web/auth

fn router(request: Request(BitString), state: State) -> Response(String) {
  let pay = state.config.payment_secret
  let attend = state.config.attend_secret

  case request.path_segments(request) {
    [key] if key == attend -> attendance(request, state)
    ["licence"] -> licence(state)
    ["the-pal-system"] -> pal_system(state)
    ["login"] -> auth.login(request, state)
    ["login", user_id, token] -> auth.login_via_token(user_id, token, state)
    ["api", "payment", key] if key == pay -> payments(request, state.config)
    _ -> web.not_found()
  }
}

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
  use user <- auth.get_user_from_session(request, db, config.signing_secret)

  let state =
    State(
      config: config,
      db: db,
      templates: templates.load(config),
      current_user: user,
      send_email: email.send(_, config),
    )

  router(request, state)
  |> response.prepend_header("x-robots-tag", "noindex")
  |> response.prepend_header("made-with", "Gleam")
  |> response.map(bit_builder.from_string)
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

  // TODO: record new attendee in database
  // TODO: ensure that email sending succeeds
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

fn payments(request: Request(BitString), _config: Config) {
  use body <- web.require_bit_string_body(request)
  use _payment <- web.ok(payment.from_json(body))

  // TODO: record payment
  // let tx_key = string.append(payment.created_at, payment.reference)
  // assert Ok(_) = case
  //   expiring_set.register_new(config.transaction_set, tx_key)
  // {
  //   True -> record_new_payment(payment, config)
  //   False -> {
  //     io.println(string.append("Discarding duplicate transaction ", tx_key))
  //     Ok(Nil)
  //   }
  // }
  response.new(200)
}
