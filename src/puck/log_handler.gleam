import gleam/io
import gleam/result
import gleam/dynamic.{Dynamic}
import gleam/erlang/atom

type EventKey {
  Level
}

pub fn log(event: Dynamic, config: Dynamic) {
  let level =
    event
    |> dynamic.field(Level, atom.from_dynamic)
    |> result.map(atom.to_string)
    |> result.unwrap("")

  case level {
    "error" -> {
      io.debug(#("Oh no!!!!", event))
      Nil
    }

    _ -> Nil
  }
}
