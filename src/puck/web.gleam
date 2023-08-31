import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Option, Some}
import puck/config.{Config}
import puck/database
import puck/user.{User}
import puck/email.{Email}
import puck/web/templates.{Templates}
import nakai
import nakai/html
import nakai/html/attrs.{Attr}
import wisp.{Response}

const login_path = "/login"

pub type Context {
  Context(
    templates: Templates,
    db: database.Connection,
    config: Config,
    current_user: Option(User),
    send_email: fn(Email) -> Nil,
    send_admin_notification: fn(String, String) -> Nil,
  )
}

pub fn require_user(ctx: Context, next: fn(User) -> Response) -> Response {
  case ctx.current_user {
    Some(user) -> next(user)
    None -> wisp.redirect(login_path)
  }
}

pub fn require_admin_user(ctx: Context, next: fn(User) -> Response) -> Response {
  use user <- require_user(ctx)
  case user.is_admin {
    True -> next(user)
    False -> wisp.not_found()
  }
}

pub fn try_(
  result: Result(a, b),
  or alternative: fn() -> Response,
  then next: fn(a) -> Response,
) -> Response {
  case result {
    Ok(value) -> next(value)
    Error(_) -> alternative()
  }
}

pub fn ok_or_404(result: Result(a, b), next: fn(a) -> Response) -> Response {
  case result {
    Ok(value) -> next(value)
    Error(_) -> wisp.not_found()
  }
}

pub fn some(
  result: Option(a),
  or alternative: fn() -> Response,
  then next: fn(a) -> Response,
) -> Response {
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
