import bcrypter
import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/crypto
import gleam/http.{Https}
import gleam/http/cookie
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/int
import gleam/list
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/string
import gleam/uri
import nakai/html
import nakai/html/attrs.{Attr}
import puck/database
import puck/email.{Email}
import puck/error.{Error}
import puck/user.{User}
import puck/web.{State}
import utility

const auth_cookie = "uid"

pub fn login(request: Request(BitString), state: State) -> Response(String) {
  // TODO: A home page to redirect to
  use <- utility.guard(
    when: state.current_user != None,
    return: web.redirect("/"),
  )

  case request.method {
    http.Get -> get_login(request)
    http.Post -> attempt_login(request, state)
    _ -> web.method_not_allowed()
  }
}

fn get_login(request: Request(BitString)) -> Response(String) {
  let query = option.unwrap(request.query, "")
  let mode = login_page_mode_from_query(request)
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(login_page(mode))
}

fn login_page_mode_from_query(request: Request(BitString)) -> LoginPageMode {
  let result = {
    let query = option.unwrap(request.query, "")
    use query <- result.then(uri.parse_query(query))
    list.key_find(query, "already-registered")
  }
  case result {
    Ok(email) -> EmailAlreadyInUse(email)
    Error(_) -> Fresh
  }
}

fn attempt_login(request: Request(BitString), state: State) -> Response(String) {
  use params <- web.require_form_urlencoded_body(request)
  use email <- web.ok(list.key_find(params, "email"))
  use user <- web.ok(user.get_by_email(state.db, email))

  let html = case user {
    Some(user) -> {
      state.send_email(login_email(user, state.db))
      email_sent_page()
    }
    None -> login_page(UserNotFound)
  }

  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn login_email(user: User, db: database.Connection) -> Email {
  assert Ok(Some(token)) = user.create_login_token(db, user.id)
  let id = int.to_string(user.id)
  let content =
    "Hello! 

Here's a link to log in: https://puck.gleam.run/login/" <> id <> "/" <> token <> "

Love,
The Midsummer crew
"

  Email(
    to_address: user.email,
    to_name: user.email,
    subject: "Midsummer Night's Tea Party Login",
    content: content,
  )
}

fn email_sent_page() -> String {
  [
    web.flamingo(),
    html.p_text([], "Thank you. We've sent you an email with a link to log in."),
  ]
  |> layout
  |> web.html_page
}

type LoginPageMode {
  Fresh
  UserNotFound
  EmailAlreadyInUse(String)
}

pub const email_already_in_use_message = "That email is already in use, would you like to log in?"

pub const email_unknown_message = "Sorry, I couldn't find anyone with with email address."

fn login_page(mode: LoginPageMode) -> String {
  let #(error, email) = case mode {
    EmailAlreadyInUse(email) -> #(
      html.p_text([], email_already_in_use_message),
      email,
    )
    UserNotFound -> #(html.p_text([], email_unknown_message), "")
    Fresh -> #(html.div([], []), "")
  }

  [
    html.form(
      [Attr("method", "POST")],
      [
        error,
        web.flamingo(),
        web.form_group(
          "Welcome, friend. What's your email?",
          web.email_input(
            "email",
            [Attr("required", "true"), attrs.value(email)],
          ),
        ),
        web.submit_input_group("Login"),
        html.p_text(
          [],
          "P.S. We use one essential 🍪 to record if you are logged in.",
        ),
      ],
    ),
  ]
  |> layout
  |> web.html_page
}

fn layout(content: List(html.Node(a))) -> html.Node(a) {
  html.main([attrs.Attr("role", "main"), attrs.class("content login")], content)
}

pub fn login_via_token(user_id: String, token: String, state: State) {
  use user_id <- web.ok(int.parse(user_id))
  use hash <- web.ok_or_404(user.get_login_token_hash(state.db, user_id))
  use hash <- web.some(hash)
  case bcrypter.verify(token, hash) {
    True -> {
      assert Ok(_) = user.delete_login_token_hash(state.db, user_id)
      web.redirect("/")
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
  // TODO: expire the cookie if it is present but there is no user
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
