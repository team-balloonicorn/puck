import gleam/http
import gleam/http/request.{Request}
import gleam/http/response
import gleam/string
import gleam/list
import gleam/int
import gleam/map.{Map}
import puck/user.{Application, User}
import puck/payment.{Payment}
import puck/web.{State}
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
  assert Ok(payments) = payment.list_all(state.db)
  assert Ok(applications) = user.list_applications(state.db)

  let html = web.html_page(dashboard_html(users, payments, applications))
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn dashboard_html(
  users: List(User),
  payments: List(Payment),
  applications: List(Application),
) {
  let applications =
    applications
    |> list.map(fn(app) { #(app.user_id, app) })
    |> map.from_list()

  html.div(
    [],
    [
      html.h1_text([], "Hi admin"),
      html.h2_text([], "Users " <> int.to_string(list.length(users))),
      html.ul([], list.map(users, user_entry(_, applications))),
      html.h2_text([], "Payments " <> int.to_string(list.length(payments))),
      html.ul([], list.map(payments, payment_entry)),
    ],
  )
}

fn user_entry(user: User, applications: Map(Int, Application)) {
  html.li(
    [],
    [
      html.Text(string.inspect(user)),
      html.br([]),
      html.Text(string.inspect(map.get(applications, user.id))),
    ],
  )
}

fn payment_entry(payment: Payment) {
  html.li([], [html.Text(string.inspect(payment))])
}
