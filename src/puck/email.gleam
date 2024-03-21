import gleam/hackney
import gleam/io
import puck/config.{type Config, Config}
import zeptomail

pub type Email {
  Email(to_address: String, to_name: String, subject: String, content: String)
}

pub fn send(email: Email, config: Config) -> Nil {
  let assert Ok(response) =
    zeptomail.Email(
      from: zeptomail.Addressee(
        name: config.email_from_name,
        address: config.email_from_address,
      ),
      to: [zeptomail.Addressee(name: email.to_name, address: email.to_address)],
      reply_to: [
        zeptomail.Addressee(
          name: config.email_replyto_name,
          address: config.email_replyto_address,
        ),
      ],
      cc: [],
      bcc: [],
      body: zeptomail.TextBody(email.content),
      subject: email.subject,
    )
    |> zeptomail.email_request(config.zeptomail_api_key)
    |> hackney.send
  let assert Ok(_) =
    response
    |> zeptomail.decode_email_response
  io.println("Email sent to " <> email.to_name)
}
