import gleam/json
import gleam/result
import gleeunit/should
import puck/payment.{Payment}
import puck/user
import tests

pub fn from_json_transfer_test() {
  "{
  \"type\": \"transaction.created\",
  \"data\": {
    \"id\": \"tx_0000AG2o6vNOP3W9owpal8\",
    \"created\": \"2022-02-01T20:47:19.022Z\",
    \"description\": \"test1234\",
    \"amount\": 100,
    \"fees\": {},
    \"currency\": \"GBP\",
    \"merchant\": null,
    \"notes\": \"test1234\",
    \"metadata\": {
      \"faster_payment\": \"true\",
      \"fps_fpid\": \"ERD182YM8O83Q24Y601020220201826608371\",
      \"fps_payment_id\": \"ERD182YM8O83Q24Y6020220201826608371\",
      \"insertion\": \"entryset_0000AG2o6v13k6ALIii0RO\",
      \"notes\": \"test1234\",
      \"trn\": \"ERD182YM8O83Q24Y60\"
    },
    \"labels\": null,
    \"attachments\": null,
    \"international\": null,
    \"category\": \"transfers\",
    \"categories\": { \"transfers\": 100 },
    \"is_load\": false,
    \"settled\": \"2022-02-02T07:00:00Z\",
    \"local_amount\": 100,
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
  |> json.decode(Ok)
  |> result.nil_error
  |> result.try(fn(d) {
    payment.from_dynamic(d)
    |> result.nil_error
  })
  |> should.equal(
    Ok(Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 100,
      counterparty: "Louis Pilfold",
      reference: "test1234",
    )),
  )
}

pub fn from_json_purchase_test() {
  "{
    \"type\": \"transaction.created\",
    \"data\": {
        \"account_id\": \"acc_00008gju41AHyfLUzBUk8A\",
        \"amount\": -350,
        \"created\": \"2015-09-04T14:28:40Z\",
        \"currency\": \"GBP\",
        \"description\": \"Ozone Coffee Roasters\",
        \"id\": \"tx_00008zjky19HyFLAzlUk7t\",
        \"category\": \"eating_out\",
        \"is_load\": false,
        \"settled\": \"2015-09-05T14:28:40Z\",
        \"merchant\": {
            \"address\": {
                \"address\": \"98 Southgate Road\",
                \"city\": \"London\",
                \"country\": \"GB\",
                \"latitude\": 51.54151,
                \"longitude\": -0.08482400000002599,
                \"postcode\": \"N1 3JD\",
                \"region\": \"Greater London\"
            },
            \"created\": \"2015-08-22T12:20:18Z\",
            \"group_id\": \"grp_00008zIcpbBOaAr7TTP3sv\",
            \"id\": \"merch_00008zIcpbAKe8shBxXUtl\",
            \"logo\": \"https://pbs.twimg.com/profile_images/527043602623389696/68_SgUWJ.jpeg\",
            \"emoji\": \"🍞\",
            \"name\": \"The De Beauvoir Deli Co.\",
            \"category\": \"eating_out\"
        }
    }
}"
  |> json.decode(Ok)
  |> result.nil_error
  |> result.try(fn(d) {
    payment.from_dynamic(d)
    |> result.nil_error
  })
  |> should.equal(
    Ok(Payment(
      id: "tx_00008zjky19HyFLAzlUk7t",
      created_at: "2015-09-04T14:28:40Z",
      amount: -350,
      counterparty: "The De Beauvoir Deli Co.",
      reference: "ozone coffee roasters",
    )),
  )
}

pub fn insert_test() {
  use conn <- tests.with_connection
  let assert Ok([]) = payment.list_all(conn)

  let payment1 =
    Payment(
      id: "tx_00008zjky19HyFLAzlUk7t",
      created_at: "2015-09-04T14:28:40Z",
      amount: 350,
      counterparty: "The De Beauvoir Deli Co.",
      reference: "ozone coffee roasters",
    )
  let payment2 =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 100,
      counterparty: "Louis Pilfold",
      reference: "test1234",
    )

  let assert Ok(True) = payment.insert(conn, payment1)
  let assert Ok(True) = payment.insert(conn, payment2)
  let assert Ok([p1, p2]) = payment.list_all(conn)
  let assert True = p1 == payment1
  let assert True = p2 == payment2
}

pub fn inserting_is_idempotent_test() {
  use conn <- tests.with_connection
  let assert Ok([]) = payment.list_all(conn)

  let payment1 =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 100,
      counterparty: "Louis Pilfold",
      reference: "test1234",
    )

  let assert Ok(True) = payment.insert(conn, payment1)
  let assert Ok(False) = payment.insert(conn, payment1)
  let assert Ok(False) = payment.insert(conn, payment1)

  let assert Ok([p1]) = payment.list_all(conn)
  let assert True = p1 == payment1
}

pub fn insert_rejects_invalid_dates_test() {
  use conn <- tests.with_connection
  let assert Ok([]) = payment.list_all(conn)

  let payment1 =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "not a date",
      amount: 100,
      counterparty: "Louis Pilfold",
      reference: "test1234",
    )

  let assert Error(_) = payment.insert(conn, payment1)
  let assert Ok([]) = payment.list_all(conn)
}

pub fn insert_discards_negative_amounts_test() {
  use conn <- tests.with_connection
  let assert Ok([]) = payment.list_all(conn)

  let payment1 =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: -1,
      counterparty: "Louis Pilfold",
      reference: "test1234",
    )

  let assert Ok(False) = payment.insert(conn, payment1)
  let assert Ok([]) = payment.list_all(conn)
}

pub fn insert_lowercases_reference_test() {
  use conn <- tests.with_connection
  let assert Ok([]) = payment.list_all(conn)

  let payment1 =
    Payment(
      id: "tx_0000AG2o6vNOP3W9owpal8",
      created_at: "2022-02-01T20:47:19.022Z",
      amount: 1,
      counterparty: "Louis Pilfold",
      reference: "TEST1234",
    )
  let assert Ok(True) = payment.insert(conn, payment1)
  let assert Ok([Payment(reference: "test1234", ..)]) = payment.list_all(conn)
}

pub fn for_reference_test() {
  use conn <- tests.with_connection
  let assert Ok([]) = payment.list_all(conn)
  let date = "2022-02-01T20:47:19.022Z"

  let p1 = Payment("tx1", date, "Lou", 1, "ref1")
  let p2 = Payment("tx2", date, "Lou", 2, "ref2")
  let p3 = Payment("tx3", date, "Lou", 2, "ref1")

  let assert Ok(True) = payment.insert(conn, p1)
  let assert Ok(True) = payment.insert(conn, p2)
  let assert Ok(True) = payment.insert(conn, p3)

  let assert Ok([p4, p5]) = payment.for_reference(conn, "ref1")
  let assert True = p4 == p1
  let assert True = p5 == p3
}

pub fn total_test() {
  use db <- tests.with_connection
  let date = "2022-02-01T20:47:19.022Z"

  let assert Ok(0) = payment.total(db)

  let assert Ok(u1) = user.insert(db, "Louis", "louis@example.com")
  let assert Ok(u2) = user.insert(db, "Jay", "jay@example.com")

  let assert Ok(True) =
    payment.insert(db, Payment("tx1", date, "Lou", 1, u1.payment_reference))
  let assert Ok(True) =
    payment.insert(db, Payment("tx2", date, "Jay", 2, u2.payment_reference))
  let assert Ok(True) =
    payment.insert(db, Payment("tx3", date, "Jay", 3, u2.payment_reference))
  let assert Ok(False) =
    payment.insert(db, Payment("tx3", date, "Other", 4, "Unknown"))

  let assert Ok(6) = payment.total(db)
}
