//// Monzo is very annoying and is sending their webhooks multiple times,
//// causing us to send multiple payment emails.
////
//// In a normal web application we could deal with this using a unique
//// constraint in the database, but we cannot do this with Google Sheets. Instead
//// we have an in-memory set of info about that transactions that we use to
//// discard duplicates with. This set is emptied once every 24 hours to avoid
//// excess memory usage.

import gleam/otp/actor
import gleam/erlang/process.{Subject}
import gleam/set.{Set}
import gleam/io

pub opaque type State {
  State(set: Set(String), subject: Subject(Message))
}

pub opaque type Message {
  Add(value: String, reply: Subject(Bool))
  ResetState
}

pub fn start() -> Result(Subject(Message), actor.StartError) {
  actor.start_spec(actor.Spec(
    init: actor_init,
    init_timeout: 500,
    loop: actor_loop,
  ))
}

/// Returns true if the value is new, false otherwise.
pub fn register_new(subject: Subject(Message), value: String) -> Bool {
  process.call(subject, Add(value, _), 500)
}

fn actor_init() -> actor.InitResult(State, Message) {
  let subject = process.new_subject()
  let state = State(subject: subject, set: set.new())
  let selector =
    process.new_selector()
    |> process.selecting(subject, fn(x) { x })
  actor.Ready(state, selector)
}

fn actor_loop(message: Message, state: State) -> actor.Next(State) {
  case message {
    ResetState -> {
      io.println("Resetting expiring set")
      let state = State(..state, set: set.new())
      let one_day = 1000 * 60 * 60 * 24
      process.send_after(state.subject, one_day, ResetState)
      actor.Continue(state)
    }

    Add(value: value, reply: reply) -> {
      let is_new = !set.contains(state.set, value)
      let state = State(..state, set: set.insert(state.set, value))
      process.send(reply, is_new)
      actor.Continue(state)
    }
  }
}
