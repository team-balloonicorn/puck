import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import gleam/result
import gleam/list
import gleam/map
import nakai/html
import nakai/html/attrs.{Attr}
import puck/user.{Application}
import puck/web.{State, p}

pub const costs = [
  #("Site fee", 300_000),
  #("Site camping fee", 80_000),
  #("Rubbish collection", 10_000),
  #("Food", 180_000),
  #("Bar", 50_000),
  #("Kitchen equipment hire", 34_000),
  #("Tables + chairs hire", 20_000),
  #("Firewood", 10_000),
  #("Transportation", 50_000),
  #("Speakers", 0),
  #("Cleaning supplies, etc", 30_000),
]

pub fn total_cost() {
  costs
  |> list.fold(0, fn(total, cost) { total + cost.1 })
}

pub const field_attended = "attended"

pub const field_pod_members = "pod-members"

pub const field_pod_attended = "pod-attended"

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
    text: "Who is in your pod?",
    key: field_pod_members,
    blurb: [
      "You and the people in your pods are responsible for each other. If
      someone in your pod is unwell, having a bad time, or otherwise needs help
      the rest of your pod will look after them.",
      "At least one of your pod should have attended Midsummer Night's Teaparty
      before.",
    ],
    kind: Text("Oberon, Titania, Nick Bottom"),
  ),
  Question(
    text: "Who in your pod has attended before?",
    key: field_pod_attended,
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

pub fn attendance(request: Request(BitString), state: State) {
  case request.method {
    http.Get -> attendance_form(state)
    http.Post -> register_attendance(request, state)
    _ -> web.method_not_allowed()
  }
}

fn register_attendance(request: Request(BitString), state: State) {
  use user <- web.require_user(state)
  use params <- web.require_form_urlencoded_body(request)
  let get_answer = fn(map, name) {
    case list.key_find(params, name) {
      Ok(value) -> map.insert(map, name, value)
      Error(_) -> map
    }
  }
  let answers = list.fold(all_fields(), map.new(), get_answer)
  assert Ok(_) = user.insert_application(state.db, user.id, answers)
  web.redirect("/")
}

fn field_html(question: Question) -> html.Node(a) {
  let field = case question.kind {
    Text(placeholder) ->
      web.text_input(
        question.key,
        [Attr("required", ""), Attr("placeholder", placeholder)],
      )

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

pub fn application_form(state: State) -> Response(String) {
  let html =
    html.main(
      [Attr("role", "main"), attrs.class("content")],
      [
        web.flamingo(),
        html.h1_text([], "Midsummer Night's Tea Party 2023"),
        html.form(
          [
            attrs.class("attendee-form"),
            attrs.action("/" <> state.config.attend_secret),
            Attr("method", "post"),
            Attr("onsubmit", "this.disable = true"),
          ],
          [
            html.div([], list.map(questions, field_html)),
            web.submit_input_group("Sign up!"),
          ],
        ),
      ],
    )
    |> web.html_page
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn attendance_form(state: State) {
  let html = web.html_page(attendance_html(state))
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn attendance_html(state: State) -> html.Node(a) {
  html.main(
    [Attr("role", "main"), attrs.class("content")],
    [
      web.flamingo(),
      html.h1_text([], "Midsummer Night's Tea Party 2023"),
      html.h2_text([], "What is it?"),
      p(
        "Midsummer is a delightful little festival in a wonderful wooded
        location. Expect fun and joy with a delightful group of people.
        If you're here you should know someone who has been before, so ask
        them!",
      ),
      html.h2_text([], "When is it?"),
      p("5pm Thursday the 8th June to 11am Monday the 12th June"),
      html.h2_text([], "Where is it"),
      p("The same site as usual, 20 minutes drive from King's Lynn in Norfolk."),
      html.h2_text([], "How much does it cost?"),
      p(
        "This is a collaborative event where people contribute what they can
        afford. We don't make any money off this event and the core team
        typically pay around £500 each. Please contribute what you can.
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
        "Yes! We will be providing the breakfast buffet, and a delicious hot
        dinner on Friday, Saturday, and Sunday.",
      ),
      p(
        "If we get enough financial contributions early enough and get enough
        kitchen volunteers we may be able to offer lunch also. We'll let you
        know if this is the case.",
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
      html.p(
        [],
        [
          html.Text(
            "Yes! So long as you are with someone who has attended before.",
          ),
          html.ol(
            [],
            [
              html.li_text(
                [],
                "You submit your details using the form on the next page.",
              ),
              html.li_text(
                [],
                "We give you a reference number and bank details on the next page.",
              ),
              html.li_text(
                [],
                "You make a bank transfer to us with these details.",
              ),
              html.li_text(
                [],
                "We send you an email confirmation and get everything ready.",
              ),
              html.li_text([], "We all have a delightful time in the woods ✨"),
            ],
          ),
          html.p(
            [],
            [
              html.Text("If you've any questions before or after payment "),
              html.a_text(
                [attrs.href("mailto:" <> state.config.help_email)],
                "email us",
              ),
              html.Text(" and we'll help you out."),
            ],
          ),
        ],
      ),
      html.div([attrs.class("heart-rule")], [html.Text("Alright, here we go")]),
      case state.current_user {
        Some(_) ->
          html.div(
            [attrs.class("center form-group")],
            [
              html.a_text(
                [attrs.class("button"), attrs.href("/")],
                "Continue to your account",
              ),
            ],
          )
        None ->
          html.form(
            [
              attrs.class("attendee-form"),
              attrs.action("/sign-up/" <> state.config.attend_secret),
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
    ],
  )
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
      result.unwrap(map.get(application.answers, question.key), "n/a")
    web.dt_dl(question.text, answer)
  })
}

pub fn costs_table() -> html.Node(a) {
  html.table(
    [],
    [
      web.table_row("Low income", "£60+"),
      web.table_row("Median income", "£80+"),
      web.table_row("High income", "£100+"),
      web.table_row("Superstar 💖", "£120+"),
    ],
  )
}
