import gleam/erlang/process
import gleam/int
import gleam/string
import puck/payment.{Payment}
import puck/routes
import puck/user
import tests
import wisp/testing

fn payload(reference: String, amount: Int) {
  "{
  \"type\": \"transaction.created\",
  \"data\": {
    \"id\": \"tx_0000AG2o6vNOP3W9owpal8\",
    \"created\": \"2022-02-01T20:47:19.022Z\",
    \"description\": \"" <> reference <> "\",
    \"amount\": " <> int.to_string(amount) <> ",
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
    \"categories\": { \"transfers\": " <> int.to_string(amount) <> " },
    \"is_load\": false,
    \"settled\": \"2022-02-02T07:00:00Z\",
    \"local_amount\": " <> int.to_string(amount) <> ",
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
  use ctx <- tests.with_context
  let assert Ok(user) = user.insert(ctx.db, "Louis", "louis@example.com")
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)
  let payload = payload(user.payment_reference, 12_000)
  let response =
    testing.post(
      "/api/payment/" <> ctx.config.payment_secret,
      [#("content-type", "application/json")],
      payload,
    )
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok([
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 12_000,
      counterparty: "Louis Pilfold",
      reference: _,
    ),
  ]) = payment.list_all(ctx.db)
  // No reference matches so no email is sent
  let assert Ok(email) = process.receive(emails, 0)
  let assert "Louis" = email.to_name
  let assert "louis@example.com" = email.to_address
  let assert "Midsummer contribution confirmation" = email.subject
  let assert True = string.contains(email.content, "£120")
  let assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_wrong_case_matching_reference_test() {
  use ctx <- tests.with_context
  let assert Ok(user) = user.insert(ctx.db, "Louis", "louis@example.com")
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)
  let payload = payload(string.uppercase(user.payment_reference), 12_000)
  let response =
    testing.post(
      "/api/payment/" <> ctx.config.payment_secret,
      [#("content-type", "application/json")],
      payload,
    )
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok([
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 12_000,
      counterparty: "Louis Pilfold",
      reference: _,
    ),
  ]) = payment.list_all(ctx.db)
  // No reference matches so no email is sent
  let assert Ok(email) = process.receive(emails, 0)
  let assert "Louis" = email.to_name
  let assert "louis@example.com" = email.to_address
  let assert "Midsummer contribution confirmation" = email.subject
  let assert True = string.contains(email.content, "£120")
  let assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_duplicate_test() {
  // Monzo likes to send the same webhook 4 times even if you return 200 as
  // they say you should.
  use ctx <- tests.with_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)

  let assert Ok(user) = user.insert(ctx.db, "Louis", "louis@example.com")
  let payment =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 12_000,
      counterparty: "Louis Pilfold",
      reference: user.payment_reference,
    )
  let assert Ok(True) = payment.insert(ctx.db, payment)

  let payload = payload(user.payment_reference, 12_000)
  let response =
    testing.post(
      "/api/payment/" <> ctx.config.payment_secret,
      [#("content-type", "application/json")],
      payload,
    )
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok([_]) = payment.list_all(ctx.db)

  // Email is not sent for the repeated webhooks
  let assert Error(Nil) = process.receive(emails, 0)
  let assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_unknown_reference_test() {
  use ctx <- tests.with_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)
  let payload = payload("m-0123456789ab", 100)
  let response =
    testing.post(
      "/api/payment/" <> ctx.config.payment_secret,
      [#("content-type", "application/json")],
      payload,
    )
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok([
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 100,
      counterparty: "Louis Pilfold",
      reference: "m-0123456789ab",
    ),
  ]) = payment.list_all(ctx.db)
  // No reference matches so no email is sent
  let assert Error(Nil) = process.receive(emails, 0)
  let assert Ok(#("Unmatched Puck payment", "Louis Pilfold m-0123456789ab £1")) =
    process.receive(notifications, 0)
}

pub fn webhook_non_positive_amount_test() {
  use ctx <- tests.with_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)
  let payload = payload("m-0123456789ab", 0)
  let response =
    testing.post(
      "/api/payment/" <> ctx.config.payment_secret,
      [#("content-type", "application/json")],
      payload,
    )
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok([]) = payment.list_all(ctx.db)
  let assert Error(Nil) = process.receive(emails, 0)
  let assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_wrong_method_test() {
  use ctx <- tests.with_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)
  let payload = payload("m-0123456789ab", 100)
  let response =
    testing.patch(
      "/api/payment/" <> ctx.config.payment_secret,
      [#("content-type", "application/json")],
      payload,
    )
    |> routes.handle_request(ctx)
  let assert 405 = response.status
  let assert Ok([]) = payment.list_all(ctx.db)
  let assert Error(Nil) = process.receive(emails, 0)
  let assert Error(Nil) = process.receive(notifications, 0)
}

pub fn webhook_wrong_secret_test() {
  use ctx <- tests.with_context
  let #(ctx, emails) = tests.track_sent_emails(ctx)
  let #(ctx, notifications) = tests.track_sent_notifications(ctx)
  let payload = payload("m-0123456789ab", 100)
  let response =
    testing.post("/api/payment/nope", [], payload)
    |> routes.handle_request(ctx)
  let assert 404 = response.status
  let assert Ok([]) = payment.list_all(ctx.db)
  let assert Error(Nil) = process.receive(emails, 0)
  let assert Error(Nil) = process.receive(notifications, 0)
}
