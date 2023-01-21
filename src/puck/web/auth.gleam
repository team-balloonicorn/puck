import bcrypter
import gleam/bit_builder.{BitBuilder}
import gleam/crypto
import gleam/http.{Https}
import gleam/http/cookie
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/int
import gleam/list
import gleam/result
import gleam/bit_string
import gleam/option.{None, Option, Some}
import puck/database
import puck/user.{User}
import puck/web.{State}
import nakai/html
import nakai/html/attrs

const auth_cookie = "uid"

pub fn login(state: State) -> Response(String) {
  case state.current_user {
    // TODO: A home page to redirect to
    Some(_) -> web.redirect("/")
    None -> {
      let html = login_page()
      response.new(200)
      |> response.prepend_header("content-type", "text/html")
      |> response.set_body(html)
    }
  }
}

fn login_page() -> String {
  [
    html.main(
      [attrs.Attr("role", "main"), attrs.class("content login")],
      [
        html.form(
          [],
          [
            html.div_text([attrs.class("flamingo")], "🦩"),
            web.form_group(
              "Welcome, friend. What's your email?",
              web.email_input([attrs.Attr("required", "true")]),
            ),
            web.submit_input_group("Login"),
            html.p_text(
              [],
              "P.S. We use one essential cookie to record if you are logged in.",
            ),
          ],
        ),
      ],
    ),
  ]
  |> web.html_page
}

// TODO: test
pub fn login_via_token(user_id: String, token: String, state: State) {
  use user_id <- web.ok(int.parse(user_id))
  use hash <- web.ok_or_404(user.get_login_token_hash(state.db, user_id))
  use hash <- web.some(hash)
  case bcrypter.verify(token, hash) {
    True -> {
      assert Ok(_) = user.delete_login_token_hash(state.db, user_id)
      web.redirect("/admin")
      |> set_signed_user_id_cookie(user_id, state.config.signing_secret)
    }
    False -> web.not_found()
  }
}

fn set_signed_user_id_cookie(
  response: Response(a),
  user_id: Int,
  signing_secret: String,
) -> Response(a) {
  <<int.to_string(user_id):utf8>>
  |> crypto.sign_message(<<signing_secret:utf8>>, crypto.Sha256)
  |> response.set_cookie(response, auth_cookie, _, cookie.defaults(Https))
}

pub fn get_user_from_session(
  request: Request(a),
  db: database.Connection,
  signing_secret: String,
  next: fn(Option(User)) -> Response(BitBuilder),
) -> Response(BitBuilder) {
  case get_user_from_cookie(request, db, signing_secret) {
    Ok(user) -> next(user)

    // If the cookie is invalid then it has either been tampered with or the
    // signing secret has changed. In either case set the cookie to expire
    // immediately.
    Error(Nil) ->
      web.not_found()
      |> expire_cookie(auth_cookie)
      |> response.map(bit_builder.from_string)
  }
}

fn get_user_from_cookie(
  request: Request(a),
  db: database.Connection,
  signing_secret: String,
) -> Result(Option(User), Nil) {
  let cookie =
    request.get_cookies(request)
    |> list.key_find(auth_cookie)
  case cookie {
    Ok(cookie) ->
      cookie
      |> crypto.verify_signed_message(<<signing_secret:utf8>>)
      |> result.then(bit_string.to_string)
      |> result.then(int.parse)
      |> result.then(fn(user_id) {
        user.get_and_increment_interaction(db, user_id)
        |> result.nil_error
      })
    Error(Nil) -> Ok(None)
  }
}

fn expire_cookie(response: Response(a), name: String) -> Response(a) {
  let attributes =
    cookie.Attributes(..cookie.defaults(Https), max_age: option.Some(0))
  response
  |> response.set_cookie(name, "", attributes)
}
