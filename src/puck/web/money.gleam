import gleam/bool
import gleam/http.{Post}
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import puck/email.{type Email, Email}
import puck/payment.{type Payment}
import puck/user.{type User}
import puck/web.{type Context}
import wisp.{type Request, type Response}

pub fn payment_webhook(request: Request, ctx: Context) -> Response {
  use <- wisp.require_method(request, Post)

  // Record payment
  use body <- wisp.require_json(request)
  use payment <- web.try_(payment.from_dynamic(body), wisp.unprocessable_entity)
  let assert Ok(newly_inserted) = payment.insert(ctx.db, payment)

  // Nothing more to do if we already knew about this payment, meaning that this
  // is a duplicate webhook.
  use <- bool.guard(!newly_inserted, return: wisp.ok())

  let assert Ok(result) =
    user.get_user_by_payment_reference(ctx.db, payment.reference)
  case result {
    // Send a confirmation email to the user, if there is one
    Some(user) -> send_payment_notification_email(user, payment, ctx)

    // Otherwise notify that this payment is unknown
    None -> {
      let details = [
        payment.counterparty,
        payment.reference,
        pence_to_pounds(payment.amount),
      ]
      ctx.send_admin_notification(
        "Unmatched Puck payment",
        string.join(details, " "),
      )
    }
  }

  wisp.ok()
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
  ctx: Context,
) -> Nil {
  let content =
    string.concat([
      "Hi

We received your contribution of ",
      pence_to_pounds(payment.amount),
      ", thank you!

Love,
The Midsummer crew

P.S.
View your details and more on the website
https://puck.midsummer.lpil.uk/

To keep up with future messages from crew join the announcement Signal group
" <> ctx.config.signal_announce <> "

To chat and organise fun with your fellow midsummer folks join the chat Signal group
" <> ctx.config.signal_chat <> "
",
    ])

  ctx.send_email(Email(
    to_name: user.name,
    to_address: user.email,
    subject: "Midsummer contribution confirmation",
    content: content,
  ))
}
