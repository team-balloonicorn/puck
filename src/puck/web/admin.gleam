import gleam/http
import gleam/http/request.{Request}
import gleam/http/response
import gleam/option.{Some}
import gleam/result
import gleam/list
import gleam/int
import gleam/map
import puck/web/event
import puck/user.{User}
import puck/payment.{Payment}
import puck/web.{State}
import puck/web/money
import nakai/html

pub fn dashboard(request: Request(BitString), state: State) {
  use _ <- web.require_admin_user(state)
  case request.method {
    http.Get -> get_dashboard(state)
    _ -> web.method_not_allowed()
  }
}

fn get_dashboard(state: State) {
  assert Ok(users) = user.list_all(state.db)
  assert Ok(paid_users_count) = user.count_users_with_payments(state.db)
  assert Ok(unmatched_payments) = payment.unmatched(state.db)
  assert Ok(daily_income) = payment.per_day(state.db)
  assert Ok(total) = payment.total(state.db)

  let user = fn(i, user) { user_row(i, user, state) }
  let payment = fn(i, payment) { payment_row(i, payment) }

  let html =
    html.div(
      [],
      [
        html.h1_text([], "Hi admin"),
        html.table(
          [],
          [
            tr([th("Total contributions"), td(money.pence_to_pounds(total))]),
            tr([th("People contributed"), td(int.to_string(paid_users_count))]),
          ],
        ),
        html.h2_text([], "People"),
        table(
          [
            "", "Name", "Email", "Visits", "Paid", "Reference", "Attended",
            "Pod", "Pod attended", "Diet", "Accessibility",
          ],
          list.index_map(users, user),
        ),
        html.h2_text([], "Unmatched payments"),
        table(
          ["", "Id", "Timestamp", "Counterparty", "Amount", "Reference"],
          list.index_map(unmatched_payments, payment),
        ),
        html.h2_text([], "Contributions"),
        table(
          ["Date", "Daily", "Cumulative"],
          list.map(daily_income, day_income),
        ),
      ],
    )

  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(web.html_page(html))
}

fn table(headings: List(String), rows: List(html.Node(a))) {
  html.table([], [html.tr([], list.map(headings, th)), ..rows])
}

fn day_income(payment: #(String, Int, Int)) {
  html.tr(
    [],
    [
      html.td([], [html.Text(payment.0)]),
      html.td([], [html.Text(money.pence_to_pounds(payment.1))]),
      html.td([], [html.Text(money.pence_to_pounds(payment.2))]),
    ],
  )
}

fn user_row(index: Int, user: User, state: State) {
  let application_data = case user.get_application(state.db, user.id) {
    Ok(Some(application)) -> {
      assert Ok(total) =
        payment.total_for_reference(state.db, application.payment_reference)
      let get = fn(key) { result.unwrap(map.get(application.answers, key), "") }
      [
        money.pence_to_pounds(total),
        application.payment_reference,
        get(event.field_attended),
        get(event.field_pod_members),
        get(event.field_pod_attended),
        get(event.field_dietary_requirements),
        get(event.field_accessibility_requirements),
      ]
    }

    _ -> ["", "", "", "", "", "", ""]
  }

  html.tr(
    [],
    list.map(
      [
        int.to_string(index + 1),
        user.name,
        user.email,
        int.to_string(user.interactions),
        ..application_data
      ],
      td,
    ),
  )
}

fn payment_row(index: Int, payment: Payment) {
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
