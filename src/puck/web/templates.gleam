import puck/config.{Config}
import gleam/string
import gleam/bbmustache as bbm

pub type Templates {
  Templates(licence: fn() -> String, submitted: fn(Submitted) -> String)
}

pub type Submitted {
  Submitted(
    help_email: String,
    account_name: String,
    account_number: String,
    sort_code: String,
    reference: String,
  )
}

pub fn load(config: Config) -> Templates {
  let licence = load_template("licence", config)
  let submitted = load_template("submitted", config)
  Templates(
    licence: fn() { licence([]) },
    submitted: submitted_template(_, submitted),
  )
}

fn submitted_template(
  data: Submitted,
  template: fn(List(#(String, bbm.Argument))) -> String,
) -> String {
  template([
    #("help_email", bbm.string(data.help_email)),
    #("account_name", bbm.string(data.account_name)),
    #("account_number", bbm.string(data.account_number)),
    #("sort_code", bbm.string(data.sort_code)),
    #("reference", bbm.string(data.reference)),
  ])
}

external fn priv_directory() -> String =
  "puck_ffi" "priv_directory"

fn load_template(
  name: String,
  config: Config,
) -> fn(List(#(String, bbm.Argument))) -> String {
  let path = string.concat([priv_directory(), "/templates/", name, ".mustache"])

  case config.reload_templates {
    True -> fn(arguments) {
      assert Ok(template) = bbm.compile_file(path)
      bbm.render(template, arguments)
    }
    False -> {
      assert Ok(template) = bbm.compile_file(path)
      fn(arguments) { bbm.render(template, arguments) }
    }
  }
}
