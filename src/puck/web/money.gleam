import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Some}
import gleam/http.{Post}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/string
import gleam/int
import puck/user.{User}
import puck/payment.{Payment}
import puck/web.{State}
import puck/email.{Email}
import utility

pub fn payment_webhook(
  request: Request(BitString),
  state: State,
) -> Response(StringBuilder) {
  let ok =
    response.new(200)
    |> response.set_body(string_builder.new())

  use <- utility.guard(request.method != Post, return: web.method_not_allowed())

  // Record payment
  use body <- web.require_bit_string_body(request)
  use payment <- web.try_(payment.from_json(body), web.unprocessable_entity)
  let assert Ok(newly_inserted) = payment.insert(state.db, payment)

  // Nothing more to do if we already knew about this payment, meaning that this
  // is a duplicate webhook.
  use <- utility.guard(!newly_inserted, return: ok)

  let assert Ok(result) =
    user.get_user_by_payment_reference(state.db, payment.reference)
  case result {
    // Send a confirmation email to the user, if there is one
    Some(user) -> send_payment_notification_email(user, payment, state)

    // Otherwise notify that this payment is unknown
    None -> {
      let details = [
        payment.counterparty,
        payment.reference,
        pence_to_pounds(payment.amount),
      ]
      state.send_admin_notification(
        "Unmatched Puck payment",
        string.join(details, " "),
      )
    }
  }

  ok
}

pub fn pence_to_pounds(pence: Int) -> String {
  let pounds = int.to_string(pence / 100)
  let pence = pence % 100
  case pence {
    0 -> "£" <> pounds
    _ -> {
      let pence = string.pad_left(int.to_string(pence), to: 2, with: "0")
      "£" <> pounds <> "." <> pence
    }
  }
}

fn send_payment_notification_email(
  user: User,
  payment: Payment,
  state: State,
) -> Nil {
  let content =
    string.concat([
      "Hi

We received your contribution of ",
      pence_to_pounds(payment.amount),
      ", thank you!

Love,
The Midsummer crew

P.S. View your details and more at https://puck.midsummer.lpil.uk/
",
    ])

  state.send_email(Email(
    to_name: user.name,
    to_address: user.email,
    subject: "Midsummer contribution confirmation",
    content: content,
  ))
}
