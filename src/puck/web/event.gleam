import gleam/dict
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import markdown
import nakai/html
import nakai/html/attrs.{Attr}
import puck/fact
import puck/user.{type Application}
import puck/web.{type Context, p}
import wisp.{type Request, type Response}

pub const costs = [
  #("Site fee", 300_000), #("Site camping fee", 80_000),
  #("Rubbish collection", 10_000), #("Food", 180_000), #("Bar", 50_000),
  #("Kitchen equipment hire", 34_000), #("Tables + chairs hire", 20_000),
  #("Firewood", 10_000), #("Transportation", 50_000), #("Speakers", 0),
  #("Cleaning supplies, etc", 30_000),
]

pub fn total_cost() {
  costs
  |> list.fold(0, fn(total, cost) { total + cost.1 })
}

pub const field_attended = "attended"

pub const field_support_network = "support-network"

pub const field_support_network_attended = "support-network-attended"

pub const field_dietary_requirements = "dietary-requirements"

pub const field_accessibility_requirements = "accessibility-requirements"

type FieldKind {
  Text(placeholder: String)
  Textarea(placeholder: String)
  Bool
}

type Question {
  Question(text: String, key: String, blurb: List(String), kind: FieldKind)
}

const questions = [
  Question(
    text: "Have you attended before?",
    key: field_attended,
    blurb: [],
    kind: Bool,
  ),
  Question(
    text: "Who is in your support network?",
    key: field_support_network,
    blurb: [
      "Your support network are the people who are responsible for you. If
      you are unwell, having a bad time, or otherwise need help then your
      support network are to look after you.",
      "If you're not sure which of your friends are going put down everyone who
      might go, and you can email us to make changes later.",
    ],
    kind: Text("Oberon, Titania, Nick Bottom"),
  ),
  Question(
    text: "Who in your support network has attended before?",
    key: field_support_network_attended,
    blurb: [],
    kind: Text("Titania"),
  ),
  Question(
    text: "Do you have any dietary requirements?",
    key: field_dietary_requirements,
    blurb: [],
    kind: Textarea(
      "Vegeterian, vegan, dairy free. Allergic to nuts, intolerant to dairy.",
    ),
  ),
  Question(
    text: "Do you have any accessibility requirements?",
    key: field_accessibility_requirements,
    blurb: [
      "Please be as detailed about what you need and we will aim to provide it
      for you as best we can.",
    ],
    kind: Textarea("I need help setting up my tent due to a back injury."),
  ),
]

fn all_fields() -> List(String) {
  questions
  |> list.map(fn(x) { x.key })
}

// TODO: fact editing
pub fn information(request: Request, ctx: Context) -> Response {
  case request.method {
    http.Get -> show_information(ctx)
    http.Post -> save_fact(request, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

// TODO: test
// TODO: test admin only
fn save_fact(request: Request, ctx: Context) -> Response {
  use _ <- web.require_admin_user(ctx)
  use form <- wisp.require_form(request)
  let params = form.values
  use detail <- web.try_(
    list.key_find(params, "detail"),
    wisp.unprocessable_entity,
  )
  use summary <- web.try_(
    list.key_find(params, "summary"),
    wisp.unprocessable_entity,
  )
  use section_id <- web.try_(
    params
      |> list.key_find("section_id")
      |> result.then(int.parse),
    wisp.unprocessable_entity,
  )
  let assert Ok(_) = fact.insert(ctx.db, section_id, summary, detail, 0.0)
  wisp.redirect("/information")
}

// TODO: test
// TODO: test form showing
fn show_information(ctx: Context) -> Response {
  use user <- web.require_user(ctx)
  let assert Ok(sections) = fact.list_all_sections(ctx.db)

  let form = case user.is_admin {
    False -> html.Nothing
    True -> {
      let assert Ok(sections) = fact.list_all_sections(ctx.db)
      let sections =
        sections
        |> list.map(fn(section) {
          html.option_text(
            [Attr("value", int.to_string(section.id))],
            section.title,
          )
        })
      html.form(
        [Attr("method", "post"), Attr("onsubmit", "this.disable = true")],
        [
          // TODO: position this properly
          html.br([]),
          html.br([]),
          html.br([]),
          html.i_text(
            [],
            "ooooh it's the special form that only shows for admins ✨",
          ),
          web.form_group(
            "Section",
            html.select([attrs.name("section_id")], sections),
          ),
          web.form_group(
            "One line summary",
            web.text_input("summary", [Attr("required", "")]),
          ),
          web.form_group(
            "Detail (markdown)",
            html.textarea_text([attrs.name("detail"), Attr("rows", "5")], ""),
          ),
          web.submit_input_group("Save new fact"),
        ],
      )
    }
  }

  let fact_html = fn(fact: fact.Fact) {
    let id = slug(fact.summary)
    html.details(
      [
        attrs.id(id),
        Attr("onclick", "window.history.pushState(null, null, '#" <> id <> "')"),
      ],
      [
        html.summary_text([], fact.summary),
        html.UnsafeInlineHtml(markdown.to_html(fact.detail)),
      ],
    )
  }

  let section_html = fn(section: fact.Section) {
    let assert Ok(facts) = fact.list_for_section(ctx.db, section.id)
    let id = slug(section.title)

    html.Fragment([
      html.h2_text([attrs.id(id)], section.title),
      html.UnsafeInlineHtml(markdown.to_html(section.blurb)),
      html.Fragment(list.map(facts, fact_html)),
    ])
  }

  let js =
    "
document.getElementById(document.location.hash.slice(1))
  ?.setAttribute('open', '')
"

  let html =
    web.html_page(
      html.main([Attr("role", "main"), attrs.class("content")], [
        web.flamingo(),
        html.h1_text([], "All the deets"),
        web.page_nav(Some(user)),
        html.p([], [
          html.Text("Can't find what you wanna know? "),
          web.mailto("Send us an email!", ctx.config.help_email),
        ]),
        html.Fragment(list.map(sections, section_html)),
        form,
        html.Element("script", [], [html.Text(js)]),
      ]),
    )

  html
  |> wisp.html_response(200)
}

pub fn attendance(request: Request, ctx: Context) -> Response {
  case request.method {
    http.Get -> attendance_form(ctx)
    http.Post -> register_attendance(request, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn register_attendance(request: Request, ctx: Context) -> Response {
  use user <- web.require_user(ctx)
  use form <- wisp.require_form(request)
  let params = form.values
  let get_answer = fn(dict, name) {
    case list.key_find(params, name) {
      Ok(value) -> dict.insert(dict, name, value)
      Error(_) -> dict
    }
  }
  let answers = list.fold(all_fields(), dict.new(), get_answer)
  let assert Ok(_) = user.insert_application(ctx.db, user.id, answers)
  wisp.redirect("/")
}

fn field_html(question: Question) -> html.Node(a) {
  let field = case question.kind {
    Text(placeholder) ->
      web.text_input(question.key, [
        Attr("required", ""),
        Attr("placeholder", placeholder),
      ])

    Textarea(placeholder) ->
      html.textarea_text(
        [
          attrs.name(question.key),
          Attr("rows", "5"),
          Attr("placeholder", placeholder),
        ],
        "",
      )

    Bool -> {
      let radio_button = fn(name, value, label_text) {
        label([
          html.input([
            attrs.type_("radio"),
            attrs.name(name),
            attrs.value(value),
            Attr("required", ""),
          ]),
          html.Text(label_text),
        ])
      }

      div([
        radio_button(question.key, "Yes", "Yes"),
        radio_button(question.key, "No", "No"),
      ])
    }
  }

  let elements = case question.blurb {
    [] -> field
    blurb ->
      blurb
      |> list.map(fn(x) { html.p_text([], x) })
      |> list.append([field])
      |> html.div([], _)
  }

  web.form_group(question.text, elements)
}

pub fn application_form(ctx: Context) -> Response {
  html.main([Attr("role", "main"), attrs.class("content")], [
    web.flamingo(),
    html.h1_text([], "Midsummer Night's Tea Party 2024"),
    web.page_nav(ctx.current_user),
    web.p(
      "One person per submission please! We need to know about everyone who is coming.",
    ),
    html.form(
      [
        attrs.class("attendee-form"),
        attrs.action("/" <> ctx.config.attend_secret),
        Attr("method", "post"),
        Attr("onsubmit", "this.disable = true"),
      ],
      [
        html.div([], list.map(questions, field_html)),
        web.submit_input_group("Sign up!"),
      ],
    ),
  ])
  |> web.html_page
  |> wisp.html_response(200)
}

fn attendance_form(ctx: Context) -> Response {
  attendance_html(ctx)
  |> web.html_page
  |> wisp.html_response(200)
}

fn attendance_html(ctx: Context) -> html.Node(a) {
  html.main([Attr("role", "main")], [
    html.div([attrs.class("content")], [
      web.flamingo(),
      html.Element("hgroup", [], [
        html.h1_text([], "Midsummer Night's Tea Party 2024"),
        html.p_text([attrs.class("center")], "Welcome, friend!"),
      ]),
    ]),
    image_grid([
      "entrance", "firepit", "roundhouse", "tea", "tipi", "flag", "belltent",
      "boat",
    ]),
    html.div([attrs.class("content")], [
      html.h2_text([], "What is it?"),
      p(
        "Midsummer is a delightful little festival in a wonderful wooded
        location. Expect fun and joy with a delightful group of people, and
        luxuries you might not expect from a little festival, such as communal
        hot meals and hot showers.
        If you're here you should know someone who has been before, so ask
        them!",
      ),
      html.h2_text([], "When is it?"),
      p("5pm Thursday the 6th June to 10am Monday the 10th June"),
      html.h2_text([], "Where is it?"),
      p(
        "A wonderful little woodland festival site, 20 minutes drive from King's
        Lynn in Norfolk.",
      ),
      html.h2_text([], "How much does it cost?"),
      p(
        "This is a collaborative event where people contribute what they can
        afford. We don't make any money off this event. Please contribute what
        you can.
        Recommended contributions:",
      ),
      costs_table(),
      p(
        "If you cannot afford this much please get in touch. No one is excluded
        from Midsummer.",
      ),
      html.h2_text([], "How many people will there be?"),
      p("We are aiming for 100 people."),
      html.h2_text([], "Will meals be included?"),
      p(
        "Yes! We will be providing breakfast and lunch buffets, and a delicious hot
        dinner on Friday, Saturday, and Sunday.",
      ),
      p(
        "We are hoping to do lunch too, just so long as we can get enough
        kitchen volunteers.",
      ),
      html.h2_text([], "What facilities are there on site?"),
      p(
        "There are flushing toilets, running water, hot showers, and a dreamy
        outdoor bath. There is no mains electricity and the kitchen cannot be
        used by people other than kitchen crew.",
      ),
      html.h2_text([], "Where will people be sleeping?"),
      p(
        "Most people will be camping (so bring your tent), but there are a
        limited number of sleeping structures. These structures will be
        allocated with priority going to people with accessibility
        requirements.",
      ),
      html.h2_text([], "Can I refund or sell my ticket?"),
      p(
        "Tickets can not be sold for safety reasons. We need to know who
        everyone is on site, any unexpected guests will be asked to leave. If we
        get enough contributions to cover our costs then we be able to offer
        refunds.",
      ),
      html.h2_text([], "Can I come?"),
      html.p([], [
        html.Text(
          "Yes! So long as you are with someone who has attended before.",
        ),
        html.ol([], [
          html.li_text(
            [],
            "You submit your details using the form on the next page.",
          ),
          html.li_text(
            [],
            "We give you a reference number and bank details on the next page.",
          ),
          html.li_text([], "You make a bank transfer to us with these details."),
          html.li_text(
            [],
            "We send you an email confirmation and get everything ready.",
          ),
          html.li_text([], "We all have a delightful time in the woods ✨"),
        ]),
        html.p([], [
          html.Text("If you've any questions before or after payment "),
          html.a_text(
            [attrs.href("mailto:" <> ctx.config.help_email)],
            "email us",
          ),
          html.Text(" and we'll help you out."),
        ]),
      ]),
      html.div([attrs.class("heart-rule")], [html.Text("Alright, here we go")]),
      case ctx.current_user {
        Some(_) ->
          html.div([attrs.class("center form-group")], [
            html.a_text(
              [attrs.class("button"), attrs.href("/")],
              "Continue to your account",
            ),
          ])
        None ->
          html.form(
            [
              attrs.class("attendee-form"),
              attrs.action("/sign-up/" <> ctx.config.attend_secret),
              Attr("method", "post"),
              Attr("onsubmit", "this.disable = true"),
            ],
            [
              web.form_group(
                "What's your name?",
                web.text_input("name", [Attr("required", "")]),
              ),
              web.form_group(
                "What's your email?",
                div([
                  p(
                    "We will use this to send you an email with additional
                    information closer to the date. Your email will be viewable
                    by the organisers and will not be shared with anyone else.",
                  ),
                  web.email_input("email", []),
                ]),
              ),
              web.submit_input_group("Let's go"),
            ],
          )
      },
    ]),
  ])
}

fn label(children) -> html.Node(a) {
  html.label([], children)
}

fn div(children) -> html.Node(a) {
  html.div([], children)
}

pub fn application_answers_list_html(
  application: Application,
) -> List(html.Node(a)) {
  questions
  |> list.map(fn(question) {
    let answer =
      result.unwrap(dict.get(application.answers, question.key), "n/a")
    web.dt_dl(question.text, answer)
  })
}

pub fn costs_table() -> html.Node(a) {
  html.table([], [
    web.table_row("Low income", "£60+"),
    web.table_row("Median income", "£80+"),
    web.table_row("High income", "£100+"),
    web.table_row("Superstar 💖", "£120+"),
  ])
}

fn slug(text: String) {
  text
  |> string.replace(" ", "-")
  |> string.lowercase
  |> string.to_graphemes
  |> list.filter(string.contains("abcdefghijklmnopqrstuvwxyz-", _))
  |> string.concat
}

fn image_grid(images: List(String)) -> html.Node(a) {
  html.div(
    [attrs.class("image-grid")],
    list.map(images, fn(image) {
      let image =
        "https://team-balloonicorn.github.io/puck/photos/" <> image <> ".jpg"
      html.a([attrs.href(image), Attr("target", "_blank")], [
        html.img([attrs.src(image)]),
      ])
    }),
  )
}
