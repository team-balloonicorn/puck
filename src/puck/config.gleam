import gleam/erlang/os

pub type Config {
  Config(
    environment: String,
    client_id: String,
    client_secret: String,
    refresh_token: String,
    spreadsheet_id: String,
    payment_secret: String,
    /// Whether to recompile templates on each request
    reload_templates: Bool,
  )
}

pub fn load_from_env_or_crash() -> Config {
  assert Ok(environment) = os.get_env("ENVIRONMENT")
  assert Ok(spreadsheet_id) = os.get_env("SPREADSHEET_ID")
  assert Ok(client_id) = os.get_env("CLIENT_ID")
  assert Ok(client_secret) = os.get_env("CLIENT_SECRET")
  assert Ok(refresh_token) = os.get_env("REFRESH_TOKEN")
  assert Ok(payment_secret) = os.get_env("PAYMENT_SECRET")
  let reload_templates = os.get_env("PAYMENT_SECRET") != Error(Nil)

  Config(
    environment: environment,
    spreadsheet_id: spreadsheet_id,
    client_id: client_id,
    client_secret: client_secret,
    refresh_token: refresh_token,
    payment_secret: payment_secret,
    reload_templates: reload_templates,
  )
}
