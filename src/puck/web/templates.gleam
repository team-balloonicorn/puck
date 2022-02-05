import gleam/bbmustache

pub type Templates {
  Templates(home: fn() -> String, licence: fn() -> String)
}

pub fn load() -> Templates {
  Templates(home: load_home(), licence: load_licence())
}

fn load_home() {
  assert Ok(home_template) =
    bbmustache.compile_file("priv/templates/home.mustache")
  fn() { bbmustache.render(home_template, []) }
}

fn load_licence() {
  assert Ok(licence_template) =
    bbmustache.compile_file("priv/templates/licence.mustache")
  fn() { bbmustache.render(licence_template, []) }
}
