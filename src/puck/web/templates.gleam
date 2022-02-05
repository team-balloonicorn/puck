import gleam/bbmustache

pub type Templates {
  Templates(
    home: fn() -> String,
    licence: fn() -> String,
    pal_system: fn() -> String,
  )
}

pub fn load() -> Templates {
  Templates(
    home: load_home(),
    licence: load_licence(),
    pal_system: load_pal_system(),
  )
}

fn load_pal_system() {
  assert Ok(pal_system_template) =
    bbmustache.compile_file("priv/templates/the_pal_system.mustache")
  fn() { bbmustache.render(pal_system_template, []) }
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
