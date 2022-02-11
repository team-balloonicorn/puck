pub type Email {
  Email(
    from_email: String,
    from_name: String,
    to: List(String),
    subject: String,
    content: String,
  )
}

pub type AuthApproach {
  Always
  IfAvailable
  Never
}

pub type Options {
  Options(
    relay: String,
    port: Int,
    username: String,
    password: String,
    ssl: Bool,
    auth: AuthApproach,
    retries: Int,
  )
}

pub external fn send(Email, Options) -> Result(Nil, Nil) =
  "gleam_gen_smtp_ffi" "send"
