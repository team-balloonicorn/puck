import puck/web
import puck/sheets
import puck/config.{Config}
import gleam/io
import gleam/erlang
import gleam/http/elli

const usage = "USAGE:

  puck server
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
    ["server"] -> server(config)
    _ -> unknown()
  }
}

fn unknown() {
  io.println(usage)
  halt(1)
}

fn server(config: Config) {
  // Start the web server process
  assert Ok(_) = elli.start(web.service(config), on_port: 3000)
  io.println("Started listening on localhost:3000 ✨")

  // Put the main process to sleep while the web server does its thing
  erlang.sleep_forever()
}

external fn halt(Int) -> Nil =
  "erlang" "halt"
