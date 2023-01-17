import gleam/erlang/os
import gleam/erlang/process.{Subject}
import puck/expiring_set

pub type Config {
  Config(
    environment: String,
    database_path: String,
    help_email: String,
    signing_secret: String,
    // Google sheets
    client_id: String,
    client_secret: String,
    refresh_token: String,
    spreadsheet_id: String,
    /// Payment webhook secret
    payment_secret: String,
    /// Secret route to sign up
    attend_secret: String,
    /// Whether to recompile templates on each request
    reload_templates: Bool,
    /// Email config
    zeptomail_api_key: String,
    email_from_address: String,
    email_from_name: String,
    email_replyto_address: String,
    email_replyto_name: String,
    // Account details
    account_name: String,
    account_number: String,
    sort_code: String,
    // Record of recently seen transactions
    transaction_set: Subject(expiring_set.Message),
  )
}

pub fn load_from_env_or_crash() -> Config {
  assert Ok(set) = expiring_set.start()

  assert Ok(environment) = os.get_env("ENVIRONMENT")
  assert Ok(database_path) = os.get_env("DATABASE_PATH")
  assert Ok(spreadsheet_id) = os.get_env("SPREADSHEET_ID")
  assert Ok(client_id) = os.get_env("CLIENT_ID")
  assert Ok(client_secret) = os.get_env("CLIENT_SECRET")
  assert Ok(refresh_token) = os.get_env("REFRESH_TOKEN")
  assert Ok(payment_secret) = os.get_env("PAYMENT_SECRET")
  assert Ok(attend_secret) = os.get_env("ATTEND_SECRET")
  assert Ok(zeptomail_api_key) = os.get_env("ZEPTOMAIL_API_KEY")
  assert Ok(email_from_address) = os.get_env("EMAIL_FROM_ADDRESS")
  assert Ok(email_from_name) = os.get_env("EMAIL_FROM_NAME")
  assert Ok(email_replyto_address) = os.get_env("EMAIL_REPLYTO_ADDRESS")
  assert Ok(email_replyto_name) = os.get_env("EMAIL_REPLYTO_NAME")
  assert Ok(account_name) = os.get_env("ACCOUNT_NAME")
  assert Ok(account_number) = os.get_env("ACCOUNT_NUMBER")
  assert Ok(sort_code) = os.get_env("SORT_CODE")
  assert Ok(help_email) = os.get_env("HELP_EMAIL")
  assert Ok(signing_secret) = os.get_env("SIGNING_SECRET")
  let reload_templates = os.get_env("RELOAD_TEMPLATES") != Error(Nil)

  Config(
    environment: environment,
    database_path: database_path,
    spreadsheet_id: spreadsheet_id,
    client_id: client_id,
    client_secret: client_secret,
    refresh_token: refresh_token,
    attend_secret: attend_secret,
    payment_secret: payment_secret,
    reload_templates: reload_templates,
    zeptomail_api_key: zeptomail_api_key,
    email_from_address: email_from_address,
    email_from_name: email_from_name,
    email_replyto_address: email_replyto_address,
    email_replyto_name: email_replyto_name,
    account_name: account_name,
    account_number: account_number,
    sort_code: sort_code,
    help_email: help_email,
    transaction_set: set,
    signing_secret: signing_secret,
  )
}
