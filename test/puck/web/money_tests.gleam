import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/string
import gleam/map
import puck/payment.{Payment}
import puck/user
import puck/web/routes
import tests

fn payload(reference: String, amount: Int) {
  "{
  \"type\": \"transaction.created\",
  \"data\": {
    \"id\": \"tx_0000AG2o6vNOP3W9owpal8\",
    \"created\": \"2022-02-01T20:47:19.022Z\",
    \"description\": \"" <> reference <> "\",
    \"amount\": " <> int.to_string(
    amount,
  ) <> ",
    \"fees\": {},
    \"currency\": \"GBP\",
    \"merchant\": null,
    \"notes\": \"" <> reference <> "\",
    \"metadata\": {
      \"faster_payment\": \"true\",
      \"fps_fpid\": \"ERD182YM8O83Q24Y601020220201826608371\",
      \"fps_payment_id\": \"ERD182YM8O83Q24Y6020220201826608371\",
      \"insertion\": \"entryset_0000AG2o6v13k6ALIii0RO\",
      \"notes\": \"" <> reference <> "\",
      \"trn\": \"ERD182YM8O83Q24Y60\"
    },
    \"labels\": null,
    \"attachments\": null,
    \"international\": null,
    \"category\": \"transfers\",
    \"categories\": { \"transfers\": " <> int.to_string(
    amount,
  ) <> " },
    \"is_load\": false,
    \"settled\": \"2022-02-02T07:00:00Z\",
    \"local_amount\": " <> int.to_string(
    amount,
  ) <> ",
    \"local_currency\": \"GBP\",
    \"updated\": \"2022-02-01T20:47:19.153Z\",
    \"account_id\": \"acc_00009QOPJC8rGUzAsElwMT\",
    \"user_id\": \"\",
    \"counterparty\": {
      \"account_number\": \"71931989\",
      \"name\": \"Louis Pilfold\",
      \"sort_code\": \"608371\",
      \"user_id\": \"anonuser_0cb393294ed66307dedc41\"
    },
    \"scheme\": \"payport_faster_payments\",
    \"dedupe_id\": \"com.monzo.fps:9200:ERD182YM8O83Q24Y601020220201826608371:INBOUND\",
    \"originator\": false,
    \"include_in_spending\": false,
    \"can_be_excluded_from_breakdown\": false,
    \"can_be_made_subscription\": false,
    \"can_split_the_bill\": false,
    \"can_add_to_tab\": false,
    \"can_match_transactions_in_categorization\": false,
    \"amount_is_pending\": false,
    \"atm_fees_detailed\": null,
    \"parent_account_id\": \"\"
  }
}"
}

pub fn webhook_matching_reference_test() {
  use state <- tests.with_state
  assert Ok(user) = user.insert(state.db, "Louis", "louis@example.com")
  assert Ok(application) = user.insert_application(state.db, user.id, map.new())
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)
  let payload = payload(application.payment_reference, 12_000)
  let response =
    tests.request("/api/payment/" <> state.config.payment_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 200 = response.status
  assert "" = response.body
  assert Ok([
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 12_000,
      counterparty: "Louis Pilfold",
      reference: _,
    ),
  ]) = payment.list_all(state.db)
  // No reference matches so no email is sent
  assert Ok(email) = process.receive(emails, 0)
  assert "Louis" = email.to_name
  assert "louis@example.com" = email.to_address
  assert "Midsummer contribution confirmation" = email.subject
  assert True = string.contains(email.content, "£120")
  assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_wrong_case_matching_reference_test() {
  use state <- tests.with_state
  assert Ok(user) = user.insert(state.db, "Louis", "louis@example.com")
  assert Ok(application) = user.insert_application(state.db, user.id, map.new())
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)
  let payload = payload(string.uppercase(application.payment_reference), 12_000)
  let response =
    tests.request("/api/payment/" <> state.config.payment_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 200 = response.status
  assert "" = response.body
  assert Ok([
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 12_000,
      counterparty: "Louis Pilfold",
      reference: _,
    ),
  ]) = payment.list_all(state.db)
  // No reference matches so no email is sent
  assert Ok(email) = process.receive(emails, 0)
  assert "Louis" = email.to_name
  assert "louis@example.com" = email.to_address
  assert "Midsummer contribution confirmation" = email.subject
  assert True = string.contains(email.content, "£120")
  assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_duplicate_test() {
  // Monzo likes to send the same webhook 4 times even if you return 200 as
  // they say you should.
  use state <- tests.with_state
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)

  assert Ok(user) = user.insert(state.db, "Louis", "louis@example.com")
  assert Ok(application) = user.insert_application(state.db, user.id, map.new())
  let payment =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 12_000,
      counterparty: "Louis Pilfold",
      reference: application.payment_reference,
    )
  assert Ok(True) = payment.insert(state.db, payment)

  let payload = payload(application.payment_reference, 12_000)
  let response =
    tests.request("/api/payment/" <> state.config.payment_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 200 = response.status
  assert "" = response.body
  assert Ok([_]) = payment.list_all(state.db)

  // Email is not sent for the repeated webhooks
  assert Error(Nil) = process.receive(emails, 0)
  assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_unknown_reference_test() {
  use state <- tests.with_state
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)
  let payload = payload("m-0123456789ab", 100)
  let response =
    tests.request("/api/payment/" <> state.config.payment_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 200 = response.status
  assert "" = response.body
  assert Ok([
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 100,
      counterparty: "Louis Pilfold",
      reference: "m-0123456789ab",
    ),
  ]) = payment.list_all(state.db)
  // No reference matches so no email is sent
  assert Error(Nil) = process.receive(emails, 0)
  assert Ok(#("Unmatched Puck payment", "Louis Pilfold m-0123456789ab £1")) =
    process.receive(notifications, 0)
}

pub fn webhook_non_positive_amount_test() {
  use state <- tests.with_state
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)
  let payload = payload("m-0123456789ab", 0)
  let response =
    tests.request("/api/payment/" <> state.config.payment_secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 200 = response.status
  assert "" = response.body
  assert Ok([]) = payment.list_all(state.db)
  assert Error(Nil) = process.receive(emails, 0)
  assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_wrong_method_test() {
  use state <- tests.with_state
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)
  let payload = payload("m-0123456789ab", 100)
  let response =
    tests.request("/api/payment/" <> state.config.payment_secret)
    |> request.set_method(http.Get)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 405 = response.status
  assert Ok([]) = payment.list_all(state.db)
  assert Error(Nil) = process.receive(emails, 0)
  assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_wrong_secret_test() {
  use state <- tests.with_state
  let #(state, emails) = tests.track_sent_emails(state)
  let #(state, notifications) = tests.track_sent_notifications(state)
  let payload = payload("m-0123456789ab", 100)
  let response =
    tests.request("/api/payment/nope")
    |> request.set_method(http.Get)
    |> request.set_body(<<payload:utf8>>)
    |> routes.router(state)
  assert 404 = response.status
  assert Ok([]) = payment.list_all(state.db)
  assert Error(Nil) = process.receive(emails, 0)
  assert Error(Nil) = process.receive(notifications, 0)
}
