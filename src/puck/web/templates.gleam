import gleam/option.{None, Option, Some}
import puck/config.{Config}
import gleam/string
import gleam/bbmustache as bbm

pub type Templates {
  Templates(
    home: fn(String) -> String,
    licence: fn() -> String,
    pal_system: fn() -> String,
    submitted: fn(Submitted) -> String,
  )
}

pub type Submitted {
  Submitted(
    help_email: String,
    account_name: String,
    account_number: String,
    sort_code: String,
    reference: String,
    amount: Option(Int),
  )
}

pub fn load(config: Config) -> Templates {
  let home = load_template("home", config)
  let licence = load_template("licence", config)
  let pal_system = load_template("pal_system", config)
  let submitted = load_template("submitted", config)
  Templates(
    home: fn(email) { home([#("help_email", bbm.string(email))]) },
    licence: fn() { licence([]) },
    pal_system: fn() { pal_system([]) },
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
    #("amount", bbm.int(option.unwrap(data.amount, 0))),
    #(
      "rollover",
      bbm.string(case data.amount {
        None -> "yes"
        Some(_) -> ""
      }),
    ),
  ])
}

fn load_template(
  name: String,
  config: Config,
) -> fn(List(#(String, bbm.Argument))) -> String {
  let path = string.concat(["priv/templates/", name, ".mustache"])

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
