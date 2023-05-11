import puck/config.{Config}
import gleam/string
import gleam/bbmustache as bbm

pub type Templates {
  Templates(licence: fn() -> String)
}

pub fn load(config: Config) -> Templates {
  let licence = load_template("licence", config)
  Templates(licence: fn() { licence([]) })
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
      let assert Ok(template) = bbm.compile_file(path)
      bbm.render(template, arguments)
    }
    False -> {
      let assert Ok(template) = bbm.compile_file(path)
      fn(arguments) { bbm.render(template, arguments) }
    }
  }
}
