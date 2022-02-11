import gleam/option.{None, Option, Some}
import puck/config.{Config}
import gleam/string
import gleam/bbmustache

pub type Templates {
  Templates(
    home: fn() -> String,
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
    home: fn() { home([]) },
    licence: fn() { licence([]) },
    pal_system: fn() { pal_system([]) },
    submitted: submitted_template(_, submitted),
  )
}

fn submitted_template(
  data: Submitted,
  template: fn(List(#(String, bbmustache.Argument))) -> String,
) -> String {
  template([
    #("help_email", bbmustache.string(data.help_email)),
    #("account_name", bbmustache.string(data.account_name)),
    #("account_number", bbmustache.string(data.account_number)),
    #("sort_code", bbmustache.string(data.sort_code)),
    #("reference", bbmustache.string(data.reference)),
    #("amount", bbmustache.int(option.unwrap(data.amount, 0))),
    #(
      "rollover",
      bbmustache.string(case data.amount {
        None -> "yes"
        Some(_) -> ""
      }),
    ),
  ])
}

fn load_template(
  name: String,
  config: Config,
) -> fn(List(#(String, bbmustache.Argument))) -> String {
  let path = string.concat(["priv/templates/", name, ".mustache"])

  case config.reload_templates {
    True -> fn(arguments) {
      assert Ok(template) = bbmustache.compile_file(path)
      bbmustache.render(template, arguments)
    }
    False -> {
      assert Ok(template) = bbmustache.compile_file(path)
      fn(arguments) { bbmustache.render(template, arguments) }
    }
  }
}
