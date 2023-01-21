pub fn guard(
  when predicate: Bool,
  return alternative: a,
  otherwise consequence: fn() -> a,
) -> a {
  case predicate {
    True -> alternative
    False -> consequence()
  }
}

pub fn lazy_guard(
  when predicate: Bool,
  return alternative: fn() -> a,
  otherwise consequence: fn() -> a,
) -> a {
  case predicate {
    True -> alternative()
    False -> consequence()
  }
}
