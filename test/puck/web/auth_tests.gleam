import gleam/http/response
import gleam/http/request
import gleam/int
import gleam/option.{Some}
import gleam/string
import puck/user
import puck/web/routes
import puck/web/auth
import tests

pub fn login_not_logged_in_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login")
    |> routes.router(state)
  assert 200 = response.status
  assert Error(Nil) = response.get_header(response, "location")
  assert False =
    string.contains(response.body, auth.email_already_in_use_message)
}

pub fn login_already_registered_query_param_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login")
    |> request.set_query([#("already-registered", "louis@example.com")])
    |> routes.router(state)
  assert 200 = response.status
  assert Error(Nil) = response.get_header(response, "location")
  assert True =
    string.contains(response.body, auth.email_already_in_use_message)
  assert True = string.contains(response.body, "value=\"louis@example.com\"")
}

pub fn login_logged_in_test() {
  use state <- tests.with_logged_in_state
  let response =
    tests.request("/login")
    |> routes.router(state)
  assert 302 = response.status
  assert Ok("/") = response.get_header(response, "location")
}

pub fn login_by_token_unknown_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login/1/token")
    |> routes.router(state)
  assert 404 = response.status
  assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_no_token_test() {
  use state <- tests.with_logged_in_state
  assert Some(user) = state.current_user
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/token")
    |> routes.router(state)
  assert 404 = response.status
  assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_wrong_token_test() {
  use state <- tests.with_logged_in_state
  assert Some(user) = state.current_user
  assert Ok(Some(_)) = user.create_login_token(state.db, user.id)
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/token")
    |> routes.router(state)
  assert 404 = response.status
  assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_ok_test() {
  use state <- tests.with_logged_in_state
  assert Some(user) = state.current_user
  assert Ok(Some(token)) = user.create_login_token(state.db, user.id)
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/" <> token)
    |> routes.router(state)
  assert 302 = response.status
  assert Ok("/") = response.get_header(response, "location")
  assert Ok("uid" <> _) = response.get_header(response, "set-cookie")
}
