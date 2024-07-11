import gleam/bool
import gleam/http/response
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string_builder.{type StringBuilder}
import nakai/html
import nakai/html/attrs.{Attr}
import puck/config.{type Config}
import puck/payment.{type Payment}
import puck/user.{type User}
import puck/web.{type Context, p}
import puck/web/admin
import puck/web/auth
import puck/web/event
import puck/web/money
import puck/web/templates
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req, ctx <- middleware(req, ctx)

  let pay = ctx.config.payment_secret
  let attend = ctx.config.attend_secret

  case wisp.path_segments(req) {
    [] -> home(ctx)
    [key] if key == attend -> event.attendance(req, ctx)
    ["admin"] -> admin.dashboard(req, ctx)
    ["costs"] -> costs(ctx)
    ["licence"] -> licence(ctx)
    ["information"] -> event.information(req, ctx)
    ["sign-up", key] if key == attend -> auth.sign_up(req, ctx)
    ["login"] -> auth.login(req, ctx)
    ["login", user_id, token] -> auth.login_via_token(user_id, token, ctx)
    ["api", "payment", key] if key == pay -> money.payment_webhook(req, ctx)
    _ -> wisp.not_found()
  }
  |> response.prepend_header("x-robots-tag", "noindex")
  |> response.prepend_header("made-with", "Gleam")
}

fn middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Request, Context) -> Response,
) -> Response {
  let static_directory = templates.priv_directory() <> "/static"
  let req = wisp.method_override(req)
  use <- wisp.rescue_crashes
  use <- wisp.log_request(req)
  use <- wisp.serve_static(req, from: static_directory, under: "/")

  let resp = handle_request(req, ctx)

  use <- bool.guard(when: resp.body != wisp.Empty, return: resp)

  let body = case resp.status {
    500 -> "Sorry, there was an internal server error. Please try again later."
    422 -> "Sorry, the request failed. Please try again later"
    404 -> "Sorry, the page you were looking for could not be found."
    _ -> "Sorry, something went wrong. Please try again later."
  }

  resp
  |> response.set_body(wisp.Text(string_builder.from_string(body)))
}

fn home(ctx: Context) -> Response {
  use user <- web.require_user(ctx)

  case user.attended_before {
    None -> event.application_form(ctx)
    Some(_) -> dashboard(user, ctx)
  }
}

fn dashboard(user: User, ctx: Context) -> Response {
  let assert Ok(payments) =
    payment.for_reference(ctx.db, user.payment_reference)
  let assert Ok(total) = payment.total(ctx.db)
  dashboard_html(user, payments, total, ctx.config)
  |> wisp.html_response(200)
}

fn table_row(label, value) -> html.Node(a) {
  html.tr([], [html.td_text([], label), html.td_text([], value)])
}

fn dashboard_html(
  user: User,
  payments: List(Payment),
  _total_contributions: Int,
  config: Config,
) -> StringBuilder {
  let user_contributed =
    list.fold(payments, 0, fn(total, payment) { total + payment.amount })
  let user_contributed_text = money.pence_to_pounds(user_contributed)
  // let remaining =
  //   money.pence_to_pounds(event.total_cost() - total_contributions)
  // let event_cost = money.pence_to_pounds(event.total_cost())

  let funding_section =
    html.Fragment([
      html.h2_text([], "Paying the bills"),
      html.p([], [
        // html.Text("We need " <> remaining <> " more to reach "),
        // html.a([attrs.href("/costs")], [html.Text(event_cost)]),
        // html.Text(
        //   " and break even. "
        // ),
        html.Text("You have contributed " <> user_contributed_text <> "."),
        case user_contributed > 0 {
          False -> html.Text("")
          True -> html.Text(" Thank you! 💖")
        },
      ]),
      p(
        "We don't make any money off this event. Please contribute what you can.
        Recommended contributions:",
      ),
      event.costs_table(),
      p(
        "If you cannot afford this much please get in touch. No one is excluded
        from Midsummer.",
      ),
      p(
        "Please make payments to this account using your unique reference code.",
      ),
      html.table([], [
        table_row("Account holder", config.account_name),
        table_row("Account number", config.account_number),
        table_row("Sort code", config.sort_code),
        table_row("Unique reference", user.payment_reference),
      ]),
    ])

  // TODO: permit people to edit these
  let info_list = [
    web.dt_dl("What's your name?", user.name),
    web.dt_dl("What's your email?", user.email),
    web.dt_dl("How much have you contributed?", user_contributed_text),
    html.Fragment(event.application_answers_list_html(user)),
  ]

  let expandable = fn(title, body) {
    html.details([Attr("open", "")], [html.summary_text([], title), body])
  }

  html.main([Attr("role", "main"), attrs.class("content")], [
    web.flamingo(),
    html.h1_text([], "Midsummer Night's Tea Party"),
    web.page_nav(Some(user)),
    funding_section,
    expandable("Your details", html.dl([], info_list)),
  ])
  |> web.html_page
}

fn costs(ctx: Context) -> Response {
  use user <- web.require_user(ctx)

  let total = money.pence_to_pounds(event.total_cost())
  let items =
    event.costs
    |> list.map(fn(entry) { table_row(entry.0, money.pence_to_pounds(entry.1)) })
    |> list.append([])
  let assert Ok(raised) =
    payment.total(ctx.db)
    |> result.map(money.pence_to_pounds)

  html.main([Attr("role", "main"), attrs.class("content")], [
    web.flamingo(),
    html.h1_text([], "The costs"),
    web.page_nav(Some(user)),
    p(
      "The numbers here may change as we get closer to the event if and
          prices change.",
    ),
    html.table([], items),
    p(
      "That's " <> total <> " in total. So far we have raised " <> raised <> ".",
    ),
    html.p([attrs.class("center")], [
      html.a_text([attrs.href("/")], "Back home"),
    ]),
  ])
  |> web.html_page
  |> wisp.html_response(200)
}

fn licence(ctx: Context) -> Response {
  ctx.templates.licence()
  |> string_builder.from_string
  |> wisp.html_response(200)
}
