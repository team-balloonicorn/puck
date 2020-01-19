import puck
import gleam/expect

pub fn hello_world_test() {
  puck.hello_world()
  |> expect.equal(_, "Hello, from puck!")
}
