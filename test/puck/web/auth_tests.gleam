import gleam/http/response
import puck/web/routes
import tests

pub fn login_not_logged_in_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login")
    |> routes.router(state)
  assert 200 = response.status
  assert Error(Nil) = response.get_header(response, "location")
}

pub fn login_logged_in_test() {
  use state <- tests.with_logged_in_state
  let response =
    tests.request("/login")
    |> routes.router(state)
  assert 302 = response.status
  assert Ok("/") = response.get_header(response, "location")
}
