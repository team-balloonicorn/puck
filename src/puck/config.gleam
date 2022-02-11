import gleam/erlang/os
import gleam/int

pub type Config {
  Config(
    environment: String,
    help_email: String,
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
    smtp_host: String,
    smtp_name: String,
    smtp_username: String,
    smtp_password: String,
    smtp_port: Int,
    smtp_from_email: String,
    smtp_from_name: String,
    // Account details
    account_name: String,
    account_number: String,
    sort_code: String,
  )
}

pub fn load_from_env_or_crash() -> Config {
  assert Ok(environment) = os.get_env("ENVIRONMENT")
  assert Ok(spreadsheet_id) = os.get_env("SPREADSHEET_ID")
  assert Ok(client_id) = os.get_env("CLIENT_ID")
  assert Ok(client_secret) = os.get_env("CLIENT_SECRET")
  assert Ok(refresh_token) = os.get_env("REFRESH_TOKEN")
  assert Ok(payment_secret) = os.get_env("PAYMENT_SECRET")
  assert Ok(attend_secret) = os.get_env("ATTEND_SECRET")
  assert Ok(smtp_host) = os.get_env("SMTP_HOST")
  assert Ok(smtp_name) = os.get_env("SMTP_NAME")
  assert Ok(smtp_username) = os.get_env("SMTP_USERNAME")
  assert Ok(smtp_password) = os.get_env("SMTP_PASSWORD")
  assert Ok(smtp_port) = os.get_env("SMTP_PORT")
  assert Ok(smtp_port) = int.parse(smtp_port)
  assert Ok(smtp_from_email) = os.get_env("SMTP_FROM_EMAIL")
  assert Ok(smtp_from_name) = os.get_env("SMTP_FROM_NAME")
  assert Ok(account_name) = os.get_env("ACCOUNT_NAME")
  assert Ok(account_number) = os.get_env("ACCOUNT_NUMBER")
  assert Ok(sort_code) = os.get_env("SORT_CODE")
  assert Ok(help_email) = os.get_env("HELP_EMAIL")
  let reload_templates = os.get_env("RELOAD_TEMPLATES") != Error(Nil)

  Config(
    environment: environment,
    spreadsheet_id: spreadsheet_id,
    client_id: client_id,
    client_secret: client_secret,
    refresh_token: refresh_token,
    attend_secret: attend_secret,
    payment_secret: payment_secret,
    reload_templates: reload_templates,
    smtp_host: smtp_host,
    smtp_name: smtp_name,
    smtp_username: smtp_username,
    smtp_password: smtp_password,
    smtp_port: smtp_port,
    smtp_from_email: smtp_from_email,
    smtp_from_name: smtp_from_name,
    account_name: account_name,
    account_number: account_number,
    sort_code: sort_code,
    help_email: help_email,
  )
}
