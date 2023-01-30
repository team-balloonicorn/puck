import gleam/option.{None, Some}
import gleam/http.{Post}
import gleam/http/request.{Request}
import gleam/http/response
import gleam/string
import gleam/int
import puck/user.{User}
import puck/payment.{Payment}
import puck/web.{State}
import puck/email.{Email}
import utility

pub fn payment_webhook(request: Request(BitString), state: State) {
  use <- utility.guard(request.method != Post, return: web.method_not_allowed())

  // Record payment
  use body <- web.require_bit_string_body(request)
  use payment <- web.ok(payment.from_json(body))
  assert Ok(_) = payment.insert(state.db, payment)

  // Send a confirmation email to the user, if there is one
  assert Ok(result) =
    user.get_user_by_payment_reference(state.db, payment.reference)
  case result {
    Some(user) -> send_payment_notification_email(user, payment, state)
    None -> Nil
  }

  response.new(200)
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
      "Hello!

We received your payment of ",
      pence_to_pounds(payment.amount),
      ".

Thanks,
The Midsummer crew",
    ])

  state.send_email(Email(
    to_name: user.name,
    to_address: user.email,
    subject: "Midsummer Night's Tea Party payment confirmation",
    content: content,
  ))
}
