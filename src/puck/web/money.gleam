import gleam/http.{Post}
import gleam/http/request.{Request}
import gleam/http/response
import puck/payment
import puck/web.{State}
import utility

// TODO: send payment notification email
// TODO: test
pub fn payment_webhook(request: Request(BitString), state: State) {
  use <- utility.guard(request.method != Post, return: web.method_not_allowed())

  use body <- web.require_bit_string_body(request)
  use payment <- web.ok(payment.from_json(body))
  assert Ok(_) = payment.insert(state.db, payment)
  response.new(200)
}
