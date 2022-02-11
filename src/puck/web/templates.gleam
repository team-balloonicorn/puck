import puck/config.{Config}
import gleam/string
import gleam/bbmustache

pub type Templates {
  Templates(
    home: fn() -> String,
    licence: fn() -> String,
    pal_system: fn() -> String,
    submitted: fn() -> String,
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
    submitted: fn() { submitted([]) },
  )
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
