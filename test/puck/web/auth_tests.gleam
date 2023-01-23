import gleam/http/response
import gleam/option.{Some}
import gleam/int
import puck/web/routes
import puck/user
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
