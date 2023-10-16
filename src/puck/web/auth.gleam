import gleam/string_builder.{StringBuilder}
import gleam/bit_string
import gleam/crypto
import gleam/http.{Https}
import gleam/http/cookie
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/bool
import gleam/list
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/uri
import nakai/html
import nakai/html/attrs.{Attr}
import puck/database
import puck/email.{Email}
import puck/error.{Error}
import puck/user.{User}
import puck/web.{Context}
import wisp.{Request, Response}

const auth_cookie = "uid"

pub fn login(request: Request, ctx: Context) -> Response {
  use <- bool.guard(when: ctx.current_user != None, return: wisp.redirect("/"))

  case request.method {
    http.Get -> login_form_page(request)
    http.Post -> attempt_login(request, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn login_form_page(request: Request) -> Response {
  let mode = login_page_mode_from_query(request)
  login_page_html(mode)
  |> wisp.html_response(200)
}

fn login_page_mode_from_query(request: Request) -> LoginPageMode {
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

fn attempt_login(request: Request, ctx: Context) -> Response {
  use form <- wisp.require_form(request)
  let params = form.values
  use email <- web.try_(
    list.key_find(params, "email"),
    or: wisp.unprocessable_entity,
  )
  use user <- web.try_(
    user.get_by_email(ctx.db, email),
    or: wisp.unprocessable_entity,
  )

  case user {
    Some(user) -> {
      ctx.send_email(login_email(user, ctx.db))
      login_email_sent_page()
    }
    None -> login_page_html(UserNotFound)
  }
  |> wisp.html_response(200)
}

pub fn sign_up(request: Request, ctx: Context) {
  use <- wisp.require_method(request, http.Post)

  use form <- wisp.require_form(request)
  use name <- web.try_(
    list.key_find(form.values, "name"),
    wisp.unprocessable_entity,
  )
  use email <- web.try_(
    list.key_find(form.values, "email"),
    wisp.unprocessable_entity,
  )

  case user.insert(ctx.db, name: name, email: email) {
    Ok(user) -> {
      ctx.send_email(login_email(user, ctx.db))
      login_email_sent_page()
      |> wisp.html_response(200)
    }

    Error(error.EmailAlreadyInUse) -> {
      let query = uri.query_to_string([#("already-registered", email)])
      wisp.redirect("/login?" <> query)
    }
  }
}

fn login_email(user: User, db: database.Connection) -> Email {
  let assert Ok(Some(token)) = user.get_or_create_login_token(db, user.id)
  let id = int.to_string(user.id)
  let content =
    "Hello! 

Here's a link to log in: https://puck.midsummer.lpil.uk/login/" <> id <> "/" <> token <> "

It will expire after 24 hours, so use it quick!

Love,
The Midsummer crew
"

  Email(
    to_address: user.email,
    to_name: user.name,
    subject: "Midsummer Night's Tea Party Login",
    content: content,
  )
}

fn login_email_sent_page() -> StringBuilder {
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

fn login_page_html(mode: LoginPageMode) -> StringBuilder {
  let #(error, email) = case mode {
    EmailAlreadyInUse(email) -> #(
      html.p_text([], email_already_in_use_message),
      email,
    )
    UserNotFound -> #(html.p_text([], email_unknown_message), "")
    Fresh -> #(html.Nothing, "")
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

pub fn login_via_token(user_id: String, token: String, ctx: Context) {
  // This application isn't very sensitive, so we're just comparing tokens
  // rather than doing the much more secure thing of storing and comparing
  // a hash in a constant time way.
  use user_id <- web.try_(int.parse(user_id), bad_token_page)
  use db_token <- web.try_(
    user.get_login_token_hash(ctx.db, user_id),
    bad_token_page,
  )
  use db_token <- web.some(db_token, bad_token_page)
  case token == db_token {
    True ->
      wisp.redirect("/")
      |> set_signed_user_id_cookie(user_id, ctx.config.signing_secret)
    False -> bad_token_page()
  }
}

fn bad_token_page() -> Response {
  [
    web.flamingo(),
    web.p(
      "Sorry, that link is invalid. This may be because it is too old and has
        expired, or because someone used the login page again to request a new
        link.",
    ),
    html.p(
      [],
      [
        html.Text(
          "Please check your email for a new login link. If you can't find one
            request a new one using the ",
        ),
        html.a([Attr("href", "/login")], [html.Text("login page")]),
        html.Text(
          " and use that to login, ensuring the email was received at a time
            after you used the login page to request it.",
        ),
      ],
    ),
  ]
  |> layout
  |> web.html_page
  |> wisp.html_response(422)
}

fn set_signed_user_id_cookie(
  response: Response,
  user_id: Int,
  signing_secret: String,
) -> Response {
  <<int.to_string(user_id):utf8>>
  |> crypto.sign_message(<<signing_secret:utf8>>, crypto.Sha256)
  |> response.set_cookie(response, auth_cookie, _, cookie.defaults(Https))
}

pub fn get_user_from_session(
  request: Request,
  db: database.Connection,
  signing_secret: String,
  next: fn(Option(User)) -> Response,
) -> Response {
  case get_user_from_cookie(request, db, signing_secret) {
    Ok(user) -> next(user)

    // If the cookie is invalid then it has either been tampered with or the
    // signing secret has changed. In either case set the cookie to expire
    // immediately.
    Error(Nil) ->
      wisp.not_found()
      |> expire_cookie(auth_cookie)
  }
}

fn get_user_from_cookie(
  request: Request,
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

fn expire_cookie(response: Response, name: String) -> Response {
  let attributes =
    cookie.Attributes(..cookie.defaults(Https), max_age: option.Some(0))
  response
  |> response.set_cookie(name, "", attributes)
}
