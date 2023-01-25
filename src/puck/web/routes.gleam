import gleam/bit_builder.{BitBuilder}
import gleam/erlang/process
import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import gleam/string
import gleam/list
import gleam/uri
import nakai/html
import nakai/html/attrs.{Attr}
import puck/attendee
import puck/config.{Config}
import puck/database
import puck/email
import puck/payment
import puck/error
import puck/user.{Application, User}
import puck/web.{State}
import puck/web/auth
import puck/web/print_requests
import puck/web/rescue_errors
import puck/web/static
import puck/web/templates
import utility

pub fn router(request: Request(BitString), state: State) -> Response(String) {
  let pay = state.config.payment_secret
  let attend = state.config.attend_secret

  case request.path_segments(request) {
    [] -> home(state)
    [key] if key == attend -> attendance(request, state)
    ["users"] -> users(request, state)
    ["licence"] -> licence(state)
    ["the-pal-system"] -> pal_system(state)
    ["login"] -> auth.login(request, state)
    ["login", user_id, token] -> auth.login_via_token(user_id, token, state)
    ["api", "payment", key] if key == pay -> payments(request, state.config)
    _ -> web.not_found()
  }
}

pub fn service(config: Config) {
  handle_request(_, config)
}

pub fn handle_request(
  request: Request(BitString),
  config: Config,
) -> Response(BitBuilder) {
  let request = utility.method_override(request)
  use <- rescue_errors.middleware
  use <- static.serve_assets(request)
  use <- print_requests.middleware(request)
  use db <- database.with_connection(config.database_path)
  use user <- auth.get_user_from_session(request, db, config.signing_secret)

  let state =
    State(
      config: config,
      db: db,
      templates: templates.load(config),
      current_user: user,
      send_email: email.send(_, config),
    )

  router(request, state)
  |> response.prepend_header("x-robots-tag", "noindex")
  |> response.prepend_header("made-with", "Gleam")
  |> response.map(bit_builder.from_string)
}

fn home(state: State) -> Response(String) {
  use user <- web.require_user(state)
  assert Ok(application) = user.get_application(state.db, user.id)

  case application {
    Some(application) -> dashboard(user, application, state)
    None -> application_form(state)
  }
}

fn dashboard(
  user: User,
  application: Application,
  _state: State,
) -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(
    "Hello " <> user.email <> "<br>" <> string.inspect(application),
  )
}

fn application_form(state: State) -> Response(String) {
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
                radio_button("attended", "yes", "Yes"),
                radio_button("attended", "no", "No"),
              ]),
            ),
            web.form_group(
              "What's the name of your PAL(s)?",
              div([
                p(
                  "You and your PALs are responsible for each other. At least
                  one of your PALs should have attended Midsummer Night's
                  Teaparty before.",
                ),
                html.a_text(
                  [attrs.href("/the-pal-system"), Attr("target", "_blank")],
                  "Read here for more information on the PAL system here.",
                ),
                web.text_input("pal-name", [Attr("required", "true")]),
              ]),
            ),
            web.form_group(
              "Has your PAL attended before?",
              div([
                radio_button("pal-attended", "yes", "Yes"),
                radio_button("pal-attended", "no", "No"),
              ]),
            ),
            web.form_group(
              "Do you have any dietary requirements?",
              div([
                textarea(
                  "dietary-requirements",
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
                textarea("accessibility-requirements", ""),
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

fn attendance(request: Request(BitString), state: State) {
  case request.method {
    http.Get -> attendance_form(state)
    http.Post -> register_attendance(request, state)
    _ -> web.method_not_allowed()
  }
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
          html.Text("Yes! So long as you or one of your "),
          html.a_text(
            [attrs.href("/the-pal-system"), attrs.target("_blank")],
            "PALs",
          ),
          html.Text(" has been before."),
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
              attrs.action("/users"),
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

fn register_attendance(request: Request(BitString), state: State) {
  use params <- web.require_form_urlencoded_body(request)
  use attendee <- web.ok(attendee.from_query(params))

  // TODO: record new attendee in database
  // TODO: ensure that email sending succeeds
  // Send a confirmation email to the attendee
  process.start(
    fn() {
      attendee.send_attendance_email(
        attendee.reference,
        attendee.name,
        attendee.email,
        state.config,
      )
    },
    linked: False,
  )

  let html =
    state.templates.submitted(templates.Submitted(
      help_email: state.config.help_email,
      account_name: state.config.account_name,
      account_number: state.config.account_number,
      sort_code: state.config.sort_code,
      reference: attendee.reference,
    ))

  response.new(201)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn users(request: Request(BitString), state: State) {
  use <- utility.guard(request.method != http.Post, web.method_not_allowed())
  use params <- web.require_form_urlencoded_body(request)
  use name <- web.ok(list.key_find(params, "name"))
  use email <- web.ok(list.key_find(params, "email"))
  case user.insert(state.db, name: name, email: email) {
    Ok(user) ->
      // TODO: Send login link
      // TODO: Show success page
      todo
    Error(error.EmailAlreadyInUse) -> {
      let query = uri.query_to_string([#("already-registered", email)])
      web.redirect("/login?" <> query)
    }
  }
}

fn licence(state: State) {
  let html = state.templates.licence()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn pal_system(state: State) {
  let html = state.templates.pal_system()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn payments(request: Request(BitString), _config: Config) {
  use body <- web.require_bit_string_body(request)
  use _payment <- web.ok(payment.from_json(body))

  // TODO: record payment
  // let tx_key = string.append(payment.created_at, payment.reference)
  // assert Ok(_) = case
  //   expiring_set.register_new(config.transaction_set, tx_key)
  // {
  //   True -> record_new_payment(payment, config)
  //   False -> {
  //     io.println(string.append("Discarding duplicate transaction ", tx_key))
  //     Ok(Nil)
  //   }
  // }
  response.new(200)
}
