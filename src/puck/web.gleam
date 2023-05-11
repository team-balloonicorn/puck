import gleam/bit_string
import gleam/string_builder.{StringBuilder}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Option, Some}
import gleam/uri
import puck/config.{Config}
import puck/database
import puck/user.{User}
import puck/email.{Email}
import puck/web/templates.{Templates}
import nakai
import nakai/html
import nakai/html/attrs.{Attr}

const login_path = "/login"

const please_try_again = " Please try again and contact the organisers if the problem continues."

pub type State {
  State(
    templates: Templates,
    db: database.Connection,
    config: Config,
    current_user: Option(User),
    send_email: fn(Email) -> Nil,
    send_admin_notification: fn(String, String) -> Nil,
  )
}

pub fn redirect(target: String) -> Response(StringBuilder) {
  response.new(302)
  |> response.set_header("location", target)
  |> response.set_body("You are being redirected")
  |> response.map(string_builder.from_string)
}

pub fn not_found() -> Response(StringBuilder) {
  response.new(404)
  |> response.set_body("There's nothing here.")
  |> response.map(string_builder.from_string)
}

pub fn method_not_allowed() -> Response(StringBuilder) {
  response.new(405)
  |> response.set_body("Method not allowed")
  |> response.map(string_builder.from_string)
}

pub fn unprocessable_entity() -> Response(StringBuilder) {
  response.new(422)
  |> response.set_body("Unprocessable entity." <> please_try_again)
  |> response.map(string_builder.from_string)
}

pub fn bad_request() -> Response(StringBuilder) {
  response.new(400)
  |> response.set_body("Invalid request." <> please_try_again)
  |> response.map(string_builder.from_string)
}

pub fn require_user(
  state: State,
  next: fn(User) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  case state.current_user {
    Some(user) -> next(user)
    None -> redirect(login_path)
  }
}

pub fn require_admin_user(
  state: State,
  next: fn(User) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  use user <- require_user(state)
  case user.is_admin {
    True -> next(user)
    False -> not_found()
  }
}

pub fn require_bit_string_body(
  request: Request(BitString),
  next: fn(String) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  case bit_string.to_string(request.body) {
    Ok(body) -> next(body)
    Error(_) -> bad_request()
  }
}

pub fn require_form_urlencoded_body(
  request: Request(BitString),
  next: fn(List(#(String, String))) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  use body <- require_bit_string_body(request)
  case uri.parse_query(body) {
    Ok(body) -> next(body)
    Error(_) -> unprocessable_entity()
  }
}

pub fn try_(
  result: Result(a, b),
  or alternative: fn() -> Response(StringBuilder),
  then next: fn(a) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> alternative()
  }
}

pub fn ok_or_404(
  result: Result(a, b),
  next: fn(a) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> not_found()
  }
}

pub fn some(
  result: Option(a),
  or alternative: fn() -> Response(StringBuilder),
  then next: fn(a) -> Response(StringBuilder),
) -> Response(StringBuilder) {
  case result {
    Some(value) -> next(value)
    None -> alternative()
  }
}

pub fn html_page(page_html: html.Node(a)) -> StringBuilder {
  html.div(
    [],
    [
      html.Head([
        html.meta([attrs.charset("utf-8")]),
        html.meta([
          attrs.name("viewport"),
          attrs.content("width=device-width, initial-scale=1"),
        ]),
        html.title("Midsummer Night's Tea Party"),
        html.link([
          attrs.rel("preconnect"),
          attrs.href("https://fonts.googleapis.com"),
        ]),
        html.link([
          attrs.rel("preconnect"),
          attrs.href("https://fonts.gstatic.com"),
          attrs.crossorigin(),
        ]),
        html.link([
          attrs.rel("icon"),
          attrs.type_("image/x-icon"),
          attrs.href("/assets/favicon.png"),
        ]),
        html.link([
          attrs.rel("shortcut icon"),
          attrs.type_("image/x-icon"),
          attrs.href("/assets/favicon.png"),
        ]),
        html.link([attrs.rel("stylesheet"), attrs.href("/assets/index.css")]),
        html.link([
          attrs.rel("stylesheet"),
          attrs.href(
            "https://fonts.googleapis.com/css2?family=Average&family=Quintessential&display=swap",
          ),
        ]),
      ]),
      page_html,
      html.footer(
        [attrs.class("site-footer")],
        [
          html.div(
            [],
            [
              html.Text("© Louis Pilfold. Made with "),
              html.a([attrs.href("http://gleam.run/")], [html.Text("Gleam")]),
              html.Text("."),
            ],
          ),
          html.div(
            [],
            [
              html.Text("Source code "),
              html.a_text(
                [
                  attrs.href("http://github.com/team-balloonicorn/puck"),
                  attrs.target("_blank"),
                  attrs.rel("noopener noreferrer"),
                ],
                "available",
              ),
              html.Text(" under the "),
              html.a_text(
                [attrs.href("/licence"), attrs.target("_blank")],
                "Anti-Capitalist Software Licence v1.4",
              ),
            ],
          ),
        ],
      ),
    ],
  )
  |> nakai.to_string_builder
}

pub fn form_group(label: String, input: html.Node(a)) -> html.Node(a) {
  html.div([attrs.class("form-group")], [html.label_text([], label), input])
}

pub fn email_input(name: String, attrs: List(Attr(a))) -> html.Node(a) {
  html.input([attrs.type_("email"), attrs.name(name), ..attrs])
}

pub fn text_input(name: String, attrs: List(Attr(a))) -> html.Node(a) {
  html.input([attrs.type_("text"), attrs.name(name), ..attrs])
}

pub fn submit_input_group(text: String) -> html.Node(a) {
  html.div(
    [attrs.class("form-group center")],
    [html.button_text([attrs.type_("submit")], text)],
  )
}

pub fn flamingo() -> html.Node(a) {
  html.div([attrs.class("flamingo")], [html.a_text([attrs.href("/")], "🦩")])
}

pub fn dt_dl(key: String, value: String) -> html.Node(a) {
  html.Fragment([html.dt_text([], key), html.dd_text([], value)])
}

pub fn p(text: String) -> html.Node(a) {
  html.p_text([], text)
}

pub fn table_row(label: String, value: String) -> html.Node(a) {
  html.tr([], [html.td_text([], label), html.td_text([], value)])
}

pub fn mailto(text: String, email: String) -> html.Node(a) {
  html.a([Attr("href", "mailto:" <> email)], [html.Text(text)])
}

pub fn page_nav(user: Option(User)) -> html.Node(a) {
  let admin = case user {
    Some(User(is_admin: True, ..)) ->
      html.a([attrs.href("/admin")], [html.Text("Admin")])
    _ -> html.Nothing
  }

  html.nav(
    [attrs.class("page-nav")],
    [
      html.a([attrs.href("/")], [html.Text("Home")]),
      html.a([attrs.href("/costs")], [html.Text("Costs")]),
      html.a([attrs.href("/information")], [html.Text("FAQs")]),
      admin,
    ],
  )
}
