import gleam/bbmustache

pub type Templates {
  Templates(home: fn() -> String)
}

pub fn load() -> Templates {
  Templates(home: load_home())
}

fn load_home() {
  assert Ok(home_template) =
    bbmustache.compile_file("priv/templates/home.mustache")
  fn() { bbmustache.render(home_template, []) }
}
