import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import gleam/list
import gleam/map
import nakai/html
import nakai/html/attrs.{Attr}
import puck/user
import puck/web.{State}

const field_attended = "attended"

const field_pod_members = "pod-members"

const field_pod_attended = "pod-attended"

const field_dietary_requirements = "dietary-requirements"

const field_accessibility_requirements = "accessibility-requirements"

const all_fields = [
  field_attended,
  field_pod_members,
  field_pod_attended,
  field_dietary_requirements,
  field_accessibility_requirements,
]

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
  let answers = list.fold(all_fields, map.new(), get_answer)
  assert Ok(_) = user.insert_application(state.db, user.id, answers)
  web.redirect("/")
}

pub fn application_form(state: State) -> Response(String) {
  let textarea = fn(name, placeholder) {
    html.textarea_text(
      [attrs.name(name), Attr("rows", "5"), Attr("placeholder", placeholder)],
      "",
    )
  }

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
            web.form_group(
              "Have you attended before?",
              div([
                radio_button(field_attended, "yes", "Yes"),
                radio_button(field_attended, "no", "No"),
              ]),
            ),
            web.form_group(
              "Who is in your pod?",
              div([
                p(
                  "You and the people in your pods are responsible for each other. 
                  If someone in your pod is unwell, having a bad time, or
                  otherwise needs help the rest of your pod will look after
                  them.",
                ),
                p(
                  "At least one of your PALs should have attended Midsummer
                  Night's Teaparty before.",
                ),
                web.text_input(field_pod_members, [Attr("required", "true")]),
              ]),
            ),
            web.form_group(
              "Have any of your PALs attended before?",
              div([
                radio_button(field_pod_attended, "yes", "Yes"),
                radio_button(field_pod_attended, "no", "No"),
              ]),
            ),
            web.form_group(
              "Do you have any dietary requirements?",
              div([
                textarea(
                  field_dietary_requirements,
                  "Vegeterian, vegan, dairy free. Allergic to nuts, intolerant to dairy.",
                ),
              ]),
            ),
            web.form_group(
              "Do you have any accessibility requirements?",
              div([
                p(
                  "Please be as detailed about what you need and we will aim to
                  provide it for you as best we can.",
                ),
                textarea(
                  field_accessibility_requirements,
                  "I need help setting up my tent as...",
                ),
              ]),
            ),
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
      html.h2_text([], "When is it?"),
      p("4pm Thursday the 8th June to 10am Monday the 12th June"),
      html.h2_text([], "Where is it"),
      p("The same site as usual, 20 minutes drive from King's Lynn in Norfolk."),
      html.h2_text([], "How much does it cost?"),
      // TODO: work out how much it costs
      p("TODO: work out how much it costs"),
      html.h2_text([], "How many people will there be?"),
      // TODO: Decide how many people 
      p("TODO: work out how many people"),
      html.h2_text([], "Will meals be included?"),
      // TODO: Work out meal situation
      //   <p>
      //     Due to this being last minute and the budget being very tight we are unable
      //     to do food for this event.
      //   </p>
      //   <p>
      //     If we do get enough contributions to cover the £3,450 site fee and have
      //     enough left over we look into bringing the breakfast bar, BBQs, and the
      //     drinks bar, as these can be organised quickly.
      //   </p>
      p("TODO: work out meal situation"),
      html.h2_text([], "What facilities are there on site?"),
      p(
        "There are flushing toilets, running water, hot showers, and a dreamy
        outdoor bath. There are not mains electricity or cooking facilities so
        bring your camping kit.",
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
          html.Text("Yes! So long as someone in your pod has attended before."),
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

fn p(text: String) -> html.Node(a) {
  html.p_text([], text)
}

fn div(children) -> html.Node(a) {
  html.div([], children)
}
