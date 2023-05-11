import gleam/http
import gleam/http/response
import gleam/http/request
import gleam/erlang/process
import gleam/uri
import gleam/int
import gleam/option.{Some}
import gleam/string
import gleam/string_builder
import puck/user
import puck/database
import puck/web/routes
import puck/web/auth
import tests

pub fn login_not_logged_in_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login")
    |> routes.router(state)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
  let assert False =
    response.body
    |> string_builder.to_string
    |> string.contains(auth.email_already_in_use_message)
}

pub fn login_already_registered_query_param_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login")
    |> request.set_query([#("already-registered", "louis@example.com")])
    |> routes.router(state)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains(auth.email_already_in_use_message)
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains("value=\"louis@example.com\"")
}

pub fn login_logged_in_test() {
  use state <- tests.with_logged_in_state
  let response =
    tests.request("/login")
    |> routes.router(state)
  let assert 302 = response.status
  let assert Ok("/") = response.get_header(response, "location")
}

pub fn login_by_token_unknown_test() {
  use state <- tests.with_state
  let response =
    tests.request("/login/1/token")
    |> routes.router(state)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_no_token_test() {
  use state <- tests.with_logged_in_state
  let assert Some(user) = state.current_user
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/token")
    |> routes.router(state)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_wrong_token_test() {
  use state <- tests.with_logged_in_state
  let assert Some(user) = state.current_user
  let assert Ok(Some(_)) = user.create_login_token(state.db, user.id)
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/token")
    |> routes.router(state)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_ok_test() {
  use state <- tests.with_logged_in_state
  let assert Some(user) = state.current_user
  let assert Ok(Some(token)) = user.create_login_token(state.db, user.id)
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/" <> token)
    |> routes.router(state)
  let assert 302 = response.status
  let assert Ok("/") = response.get_header(response, "location")
  let assert Ok("uid" <> _) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_expired_test() {
  use state <- tests.with_logged_in_state
  let assert Some(user) = state.current_user
  let assert Ok(Some(token)) = user.create_login_token(state.db, user.id)
  let sql = "update users set login_token_created_at = '2019-01-01 00:00:00'"
  let assert Ok(Nil) = database.exec(sql, state.db)
  let response =
    tests.request("/login/" <> int.to_string(user.id) <> "/" <> token)
    |> routes.router(state)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn sign_up_already_taken_test() {
  use state <- tests.with_logged_in_state
  let #(state, emails) = tests.track_sent_emails(state)
  let assert Some(user) = state.current_user
  let body = uri.query_to_string([#("email", user.email), #("name", "Louis")])
  let response =
    tests.request("/sign-up/" <> state.config.attend_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<body:utf8>>)
    |> routes.router(state)
  let assert 302 = response.status
  let assert Ok("/login?already-registered=puck%40example.com") =
    response.get_header(response, "location")
  let assert Error(Nil) = process.receive(emails, 0)
}

pub fn sign_up_ok_test() {
  use state <- tests.with_state
  let #(state, emails) = tests.track_sent_emails(state)
  let body =
    uri.query_to_string([#("email", "louis@example.com"), #("name", "Louis")])
  let response =
    tests.request("/sign-up/" <> state.config.attend_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<body:utf8>>)
    |> routes.router(state)
  let assert 200 = response.status
  let assert Ok(email) = process.receive(emails, 0)
  let assert "Louis" = email.to_name
  let assert "louis@example.com" = email.to_address
  let assert "Midsummer Night's Tea Party Login" = email.subject
}
