import gleam/gen_smtp.{Email}
import puck/config.{Config}

pub fn send(email: Email, config: Config) -> Result(Nil, Nil) {
  let options =
    gen_smtp.Options(
      relay: config.smtp_host,
      port: config.smtp_port,
      username: config.smtp_username,
      password: config.smtp_password,
      auth: gen_smtp.Always,
      ssl: True,
      retries: 2,
    )

  gen_smtp.send(email, options)
}
