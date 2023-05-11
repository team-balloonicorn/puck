import gleam/http/response
import puck/web/routes
import tests

pub fn unknown_page_test() {
  use state <- tests.with_state
  let response =
    tests.request("/wibble")
    |> routes.router(state)
  let assert 404 = response.status
}

pub fn licence_page_test() {
  use state <- tests.with_state
  let response =
    tests.request("/licence")
    |> routes.router(state)
  let assert 200 = response.status
}

pub fn home_not_logged_in_test() {
  use state <- tests.with_state
  let response =
    tests.request("/")
    |> routes.router(state)
  let assert 302 = response.status
  let assert Ok("/login") = response.get_header(response, "location")
}

pub fn home_logged_in_test() {
  use state <- tests.with_logged_in_state
  let response =
    tests.request("/")
    |> routes.router(state)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
}

pub fn costs_not_logged_in_test() {
  use state <- tests.with_state
  let response =
    tests.request("/costs")
    |> routes.router(state)
  let assert 302 = response.status
  let assert Ok("/login") = response.get_header(response, "location")
}

pub fn costs_logged_in_test() {
  use state <- tests.with_logged_in_state
  let response =
    tests.request("/costs")
    |> routes.router(state)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
}
