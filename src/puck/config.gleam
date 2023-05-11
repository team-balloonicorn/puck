import gleam/erlang/os

pub type Config {
  Config(
    environment: String,
    database_path: String,
    help_email: String,
    signing_secret: String,
    /// Notifications
    pushover_key: String,
    pushover_user: String,
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
  )
}

pub fn load_from_env_or_crash() -> Config {
  let assert Ok(environment) = os.get_env("ENVIRONMENT")
  let assert Ok(database_path) = os.get_env("DATABASE_PATH")
  let assert Ok(pushover_key) = os.get_env("PUSHOVER_KEY")
  let assert Ok(pushover_user) = os.get_env("PUSHOVER_USER")
  let assert Ok(payment_secret) = os.get_env("PAYMENT_SECRET")
  let assert Ok(attend_secret) = os.get_env("ATTEND_SECRET")
  let assert Ok(zeptomail_api_key) = os.get_env("ZEPTOMAIL_API_KEY")
  let assert Ok(email_from_address) = os.get_env("EMAIL_FROM_ADDRESS")
  let assert Ok(email_from_name) = os.get_env("EMAIL_FROM_NAME")
  let assert Ok(email_replyto_address) = os.get_env("EMAIL_REPLYTO_ADDRESS")
  let assert Ok(email_replyto_name) = os.get_env("EMAIL_REPLYTO_NAME")
  let assert Ok(account_name) = os.get_env("ACCOUNT_NAME")
  let assert Ok(account_number) = os.get_env("ACCOUNT_NUMBER")
  let assert Ok(sort_code) = os.get_env("SORT_CODE")
  let assert Ok(help_email) = os.get_env("HELP_EMAIL")
  let assert Ok(signing_secret) = os.get_env("SIGNING_SECRET")
  let reload_templates = os.get_env("RELOAD_TEMPLATES") != Error(Nil)

  Config(
    environment: environment,
    database_path: database_path,
    pushover_key: pushover_key,
    pushover_user: pushover_user,
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
    signing_secret: signing_secret,
  )
}
