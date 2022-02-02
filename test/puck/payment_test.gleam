import gleeunit/should
import puck/payment.{Payment}

pub fn from_json_ok_test() {
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
  |> payment.from_json
  |> should.equal(Ok(Payment(
    created_at: "2022-02-01T20:47:19.022Z",
    amount: 100,
    counterparty: "Louis Pilfold",
    reference: "test1234",
  )))
}