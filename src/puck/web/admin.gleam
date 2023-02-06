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
  assert Ok(unmatched_payments) = payment.unmatched(state.db)
  assert Ok(total) = payment.total(state.db)
  let user = fn(i, user) { user_row(i, user, state) }
  let payment = fn(i, payment) { payment_row(i, payment) }

  let html =
    html.div(
      [],
      [
        html.h1_text([], "Hi admin"),
        html.p_text([], "Total contributions: " <> money.pence_to_pounds(total)),
        html.h2_text([], "Users"),
        html.table([], [user_header(), ..list.index_map(users, user)]),
        html.h2_text([], "Unmatched payments"),
        html.table(
          [],
          [payment_header(), ..list.index_map(unmatched_payments, payment)],
        ),
      ],
    )

  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(web.html_page(html))
}

fn user_header() {
  html.tr(
    [],
    [
      html.th([], []),
      html.th([], [html.Text("Name")]),
      html.th([], [html.Text("Email")]),
      html.th([], [html.Text("Visits")]),
      html.th([], [html.Text("Paid")]),
      html.th([], [html.Text("Reference")]),
      html.th([], [html.Text("Attended")]),
      html.th([], [html.Text("Pod")]),
      html.th([], [html.Text("Pod attended")]),
      html.th([], [html.Text("Diet")]),
      html.th([], [html.Text("Accessibility")]),
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
      fn(text) { html.td([], [html.Text(text)]) },
    ),
  )
}

fn payment_header() {
  html.tr(
    [],
    [
      html.th([], []),
      html.th([], [html.Text("Id")]),
      html.th([], [html.Text("Timestamp")]),
      html.th([], [html.Text("Counterparty")]),
      html.th([], [html.Text("Amount")]),
      html.th([], [html.Text("Reference")]),
    ],
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
      fn(text) { html.td([], [html.Text(text)]) },
    ),
  )
}
