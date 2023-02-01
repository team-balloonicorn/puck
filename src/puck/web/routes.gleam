import gleam/bit_builder.{BitBuilder}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import gleam/list
import puck/config.{Config}
import puck/database
import puck/payment.{Payment}
import puck/email
import puck/user.{Application, User}
import puck/web.{State, p}
import puck/web/money
import puck/web/auth
import puck/web/event
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/web/templates
import nakai/html
import nakai/html/attrs.{Attr}
import utility

pub fn router(request: Request(BitString), state: State) -> Response(String) {
  let pay = state.config.payment_secret
  let attend = state.config.attend_secret

  case request.path_segments(request) {
    [] -> home(state)
    [key] if key == attend -> event.attendance(request, state)
    ["licence"] -> licence(state)
    ["sign-up", key] if key == attend -> auth.sign_up(request, state)
    ["login"] -> auth.login(request, state)
    ["login", user_id, token] -> auth.login_via_token(user_id, token, state)
    ["api", "payment", key] if key == pay ->
      money.payment_webhook(request, state)
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
  state: State,
) -> Response(String) {
  assert Ok(payments) =
    payment.for_reference(state.db, application.payment_reference)
  assert Ok(total) = payment.total(state.db)

  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(dashboard_html(
    user,
    application,
    payments,
    total,
    state.config,
  ))
}

fn dashboard_html(
  user: User,
  application: Application,
  payments: List(Payment),
  total_contributions: Int,
  config: Config,
) -> String {
  let user_contributed =
    payments
    |> list.fold(0, fn(total, payment) { total + payment.amount })
    |> money.pence_to_pounds
  let remaining = money.pence_to_pounds(event.total_cost - total_contributions)
  let event_cost = money.pence_to_pounds(event.total_cost)

  let table_row = fn(label, value) {
    html.tr([], [html.td_text([], label), html.td_text([], value)])
  }

  let funding_section =
    html.Fragment([
      html.h2_text([], "Paying the bills"),
      // TODO: link to costs breakdown page
      // TODO: add contribtion amount recommendations
      p(
        "We need " <> remaining <> " more to reach " <> event_cost <> " and
        break even. You have contributed " <> user_contributed <> ".",
      ),
      p(
        "We don't make any money off this event and the core team typically pay
        over £500 each. Please contribute what you can. We recommend £XXXX.",
      ),
      html.table(
        [],
        [
          table_row("Account holder", config.account_name),
          table_row("Account number", config.account_number),
          table_row("Sort code", config.sort_code),
          table_row("Unique reference", application.payment_reference),
        ],
      ),
    ])

  // TODO: permit people to edit these
  let info_list = [
    web.dt_dl("What's your name?", user.name),
    web.dt_dl("What's your email?", user.email),
    web.dt_dl("How much have you contributed?", user_contributed),
    html.Fragment(event.application_answers_list_html(application)),
  ]

  let expandable = fn(title, body) {
    html.details([], [html.summary_text([], title), body])
  }

  html.main(
    [Attr("role", "main"), attrs.class("content")],
    [
      web.flamingo(),
      html.h1_text([], "Midsummer Night's Tea Party"),
      funding_section,
      expandable("Your details", html.dl([], info_list)),
    ],
  )
  |> web.html_page
}

fn licence(state: State) {
  let html = state.templates.licence()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}
