import puck/user.{User}
import puck/config.{Config}
import puck/database
import puck/web/templates.{Templates}
import gleam/http.{Https}
import gleam/http/cookie
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_string
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/list
import gleam/uri
import gleam/int
import gleam/crypto

const auth_cookie = "uid"

const login_path = "/login"

pub type State {
  State(templates: Templates, db: database.Connection, config: Config)
}

pub fn set_signed_user_id_cookie(
  response: Response(a),
  user_id: Int,
  signing_secret: String,
) -> Response(a) {
  <<int.to_string(user_id):utf8>>
  |> crypto.sign_message(<<signing_secret:utf8>>, crypto.Sha256)
  |> response.set_cookie(response, auth_cookie, _, cookie.defaults(Https))
}

pub fn authenticate(
  request: Request(a),
  state: State,
  next: fn(User) -> Response(String),
) -> Response(String) {
  case get_user_from_cookie(request, state.db, state.config.signing_secret) {
    Ok(user) -> next(user)

    // If the cookie is invalid then it has either been tampered with or the
    // signing secret has changed. In either case set the cookie to expire
    // immediately.
    // If there was no cookie then there's no harm in saying to delete it.
    Error(Nil) ->
      redirect(login_path)
      |> expire_cookie(auth_cookie)
  }
}

fn get_user_from_cookie(
  request: Request(a),
  db: database.Connection,
  signing_secret: String,
) -> Result(User, Nil) {
  request.get_cookies(request)
  |> list.key_find(auth_cookie)
  |> result.then(verify_signed_cookie(_, signing_secret))
  |> result.then(int.parse)
  |> result.then(fn(user_id) {
    user.get_and_increment_interaction(db, user_id)
    |> result.nil_error
  })
  |> result.then(option.to_result(_, Nil))
}

fn verify_signed_cookie(
  cookie: String,
  signing_secret: String,
) -> Result(String, Nil) {
  crypto.verify_signed_message(cookie, <<signing_secret:utf8>>)
  |> result.then(bit_string.to_string)
}

fn expire_cookie(response: Response(a), name: String) -> Response(a) {
  let attributes =
    cookie.Attributes(..cookie.defaults(Https), max_age: option.Some(0))
  response
  |> response.set_cookie(name, "", attributes)
}

pub fn redirect(target: String) -> Response(String) {
  response.new(302)
  |> response.set_header("Location", target)
  |> response.set_body("You are being redirected")
}

pub fn not_found() -> Response(String) {
  response.new(404)
  |> response.set_body("There's nothing here...")
}

pub fn method_not_allowed() -> Response(String) {
  response.new(405)
  |> response.set_body("Method not allowed")
}

pub fn unprocessable_entity() -> Response(String) {
  response.new(422)
  |> response.set_body(
    "Unprocessable entity. Please try again and contact the organisers if the problem continues",
  )
}

pub fn bad_request() -> Response(String) {
  response.new(400)
  |> response.set_body(
    "Invalid request. Please try again and contact the organisers if the problem continues",
  )
}

pub fn require_bit_string_body(
  request: Request(BitString),
  next: fn(String) -> Response(String),
) -> Response(String) {
  case bit_string.to_string(request.body) {
    Ok(body) -> next(body)
    Error(_) -> bad_request()
  }
}

pub fn require_form_urlencoded_body(
  request: Request(BitString),
  next: fn(List(#(String, String))) -> Response(String),
) -> Response(String) {
  use body <- require_bit_string_body(request)
  case uri.parse_query(body) {
    Ok(body) -> next(body)
    Error(_) -> unprocessable_entity()
  }
}

pub fn ok(
  result: Result(a, b),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> unprocessable_entity()
  }
}

pub fn ok_or_404(
  result: Result(a, b),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> not_found()
  }
}

pub fn some(
  result: Option(a),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Some(value) -> next(value)
    None -> not_found()
  }
}

pub fn true_or_404(
  result: Bool,
  next: fn() -> Response(String),
) -> Response(String) {
  case result {
    True -> next()
    False -> not_found()
  }
}
