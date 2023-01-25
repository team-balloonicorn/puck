import gleam/bit_builder.{BitBuilder}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import gleam/string
import puck/config.{Config}
import puck/database
import puck/email
import puck/payment
import puck/user.{Application, User}
import puck/web.{State}
import puck/web/auth
import puck/web/event
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/web/templates
import utility

pub fn router(request: Request(BitString), state: State) -> Response(String) {
  let pay = state.config.payment_secret
  let attend = state.config.attend_secret

  case request.path_segments(request) {
    [] -> home(state)
    [key] if key == attend -> event.attendance(request, state)
    ["licence"] -> licence(state)
    ["the-pal-system"] -> pal_system(state)
    ["sign-up", key] if key == attend -> auth.sign_up(request, state)
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
  let request = utility.method_override(request)
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

fn home(state: State) -> Response(String) {
  use user <- web.require_user(state)
  assert Ok(application) = user.get_application(state.db, user.id)

  case application {
    Some(application) -> dashboard(user, application, state)
    None -> event.application_form(state)
  }
}

fn dashboard(
  user: User,
  application: Application,
  _state: State,
) -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(
    "Hello " <> user.email <> "<br>" <> string.inspect(application),
  )
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
