import gleam/http
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import nakai/html
import puck/payment.{type Payment}
import puck/user.{type User}
import puck/web.{type Context}
import puck/web/money
import wisp.{type Request, type Response}

pub fn dashboard(request: Request, ctx: Context) -> Response {
  use <- wisp.require_method(request, http.Get)
  use _ <- web.require_admin_user(ctx)

  let assert Ok(users) = user.list_all(ctx.db)
  let assert Ok(paid_users_count) = user.count_users_with_payments(ctx.db)
  let assert Ok(unmatched_payments) = payment.unmatched(ctx.db)
  let assert Ok(daily_income) = payment.per_day(ctx.db)
  let assert Ok(total) = payment.total(ctx.db)

  let user = fn(user) { user_row(user, ctx) }
  let payment = fn(payment, i) { payment_row(i, payment) }

  html.div([], [
    html.h1_text([], "Hi admin"),
    html.table([], [
      tr([th("People signed up"), td(int.to_string(list.length(users)))]),
      tr([th("People contributed"), td(int.to_string(paid_users_count))]),
      tr([th("Total contributions"), td(money.pence_to_pounds(total))]),
    ]),
    html.h2_text([], "People"),
    table(
      [
        "Id", "Name", "Email", "Visits", "Paid", "Reference", "Attended",
        "Support network", "Support network attended", "Diet", "Accessibility",
      ],
      list.map(users, user),
    ),
    html.h2_text([], "Unmatched payments"),
    table(
      ["", "Id", "Timestamp", "Counterparty", "Amount", "Reference"],
      list.index_map(unmatched_payments, payment),
    ),
    html.h2_text([], "Contributions"),
    table(["Date", "Daily", "Cumulative"], list.map(daily_income, day_income)),
  ])
  |> web.html_page
  |> wisp.html_response(200)
}

fn table(headings: List(String), rows: List(html.Node(a))) -> html.Node(a) {
  html.table([], [html.tr([], list.map(headings, th)), ..rows])
}

fn day_income(payment: #(String, Int, Int)) -> html.Node(a) {
  html.tr([], [
    html.td([], [html.Text(payment.0)]),
    html.td([], [html.Text(money.pence_to_pounds(payment.1))]),
    html.td([], [html.Text(money.pence_to_pounds(payment.2))]),
  ])
}

fn user_row(user: User, ctx: Context) -> html.Node(a) {
  let assert Ok(total) =
    payment.total_for_reference(ctx.db, user.payment_reference)

  let user_data = [
    money.pence_to_pounds(total),
    user.payment_reference,
    user.attended_before |> option.map(string.inspect) |> option.unwrap(""),
    user.support_network,
    user.support_network_attended,
    user.dietary_requirements,
    user.accessibility_requirements,
  ]

  html.tr(
    [],
    list.map(
      [
        int.to_string(user.id),
        user.name,
        user.email,
        int.to_string(user.interactions),
        ..user_data
      ],
      td,
    ),
  )
}

fn payment_row(index: Int, payment: Payment) -> html.Node(a) {
  html.tr(
    [],
    list.map(
      [
        int.to_string(index + 1),
        payment.id,
        payment.created_at,
        payment.counterparty,
        money.pence_to_pounds(payment.amount),
        payment.reference,
      ],
      td,
    ),
  )
}

fn tr(children: List(html.Node(a))) -> html.Node(a) {
  html.tr([], children)
}

fn th(text: String) -> html.Node(a) {
  html.th([], [html.Text(text)])
}

fn td(text: String) -> html.Node(a) {
  html.td([], [html.Text(text)])
}
