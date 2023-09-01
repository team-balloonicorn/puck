import gleam/http/response
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import gleam/string
import puck/user
import puck/database
import puck/routes
import puck/web/auth
import tests
import wisp/testing

pub fn login_not_logged_in_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/login", [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
  let assert False =
    response
    |> testing.string_body
    |> string.contains(auth.email_already_in_use_message)
}

pub fn login_already_registered_query_param_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/login?already-registered=louis@example.com", [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
  let assert True =
    response
    |> testing.string_body
    |> string.contains(auth.email_already_in_use_message)
  let assert True =
    response
    |> testing.string_body
    |> string.contains("value=\"louis@example.com\"")
}

pub fn login_logged_in_test() {
  use ctx <- tests.with_logged_in_context
  let response =
    testing.get("/login", [])
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/") = response.get_header(response, "location")
}

pub fn login_by_token_unknown_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/login/1/token", [])
    |> routes.handle_request(ctx)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_no_token_test() {
  use ctx <- tests.with_logged_in_context
  let assert Some(user) = ctx.current_user
  let response =
    testing.get("/login/" <> int.to_string(user.id) <> "/token", [])
    |> routes.handle_request(ctx)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_wrong_token_test() {
  use ctx <- tests.with_logged_in_context
  let assert Some(user) = ctx.current_user
  let assert Ok(Some(_)) = user.create_login_token(ctx.db, user.id)
  let response =
    testing.get("/login/" <> int.to_string(user.id) <> "/token", [])
    |> routes.handle_request(ctx)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_ok_test() {
  use ctx <- tests.with_logged_in_context
  let assert Some(user) = ctx.current_user
  let assert Ok(Some(token)) = user.create_login_token(ctx.db, user.id)
  let response =
    testing.get("/login/" <> int.to_string(user.id) <> "/" <> token, [])
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/") = response.get_header(response, "location")
  let assert Ok("uid" <> _) = response.get_header(response, "set-cookie")
}

pub fn login_by_token_expired_test() {
  use ctx <- tests.with_logged_in_context
  let assert Some(user) = ctx.current_user
  let assert Ok(Some(token)) = user.create_login_token(ctx.db, user.id)
  let sql = "update users set login_token_created_at = '2019-01-01 00:00:00'"
  let assert Ok(Nil) = database.exec(sql, ctx.db)
  let response =
    testing.get("/login/" <> int.to_string(user.id) <> "/" <> token, [])
    |> routes.handle_request(ctx)
  let assert 422 = response.status
  let assert Error(_) = response.get_header(response, "set-cookie")
}

pub fn sign_up_already_taken_test() {
  use ctx <- tests.with_logged_in_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let assert Some(user) = ctx.current_user
  let form = [#("email", user.email), #("name", "Louis")]
  let response =
    testing.post_form("/sign-up/" <> ctx.config.attend_secret, [], form)
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/login?already-registered=puck%40example.com") =
    response.get_header(response, "location")
  let assert Error(Nil) = process.receive(emails, 0)
}

pub fn sign_up_ok_test() {
  use ctx <- tests.with_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let form = [#("email", "louis@example.com"), #("name", "Louis")]
  let response =
    testing.post_form("/sign-up/" <> ctx.config.attend_secret, [], form)
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok(email) = process.receive(emails, 0)
  let assert "Louis" = email.to_name
  let assert "louis@example.com" = email.to_address
  let assert "Midsummer Night's Tea Party Login" = email.subject
}
