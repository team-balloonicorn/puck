import gleam/result
import gleam/list
import gleam/http
import gleam/http/request.{Request}

// TODO: gleam/bool
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

// TODO: gleam/bool
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

// TODO: gleam/http/request
/// This function overrides an incoming POST request with a method given in
/// the request's `_method` query paramerter. This is useful as web browsers
/// typically only support GET and POST requests, but our application may
/// expect other HTTP methods that are more semantically correct.
///
/// The methods PUT, PATCH, and DELETE are accepted for overriding, all others
/// are ignored.
///
/// The `_method` query paramerter can be specified in a HTML form like so:
///
///    <form method="POST" action="/item/1?_method=DELETE">
///      <button type="submit">Delete item</button>
///    </form>
///
pub fn method_override(request: Request(a)) -> Request(a) {
  use <- guard(when: request.method != http.Post, return: request)
  {
    use query <- result.then(request.get_query(request))
    use pair <- result.then(list.key_pop(query, "_method"))
    use method <- result.then(http.parse_method(pair.0))

    Ok(case method {
      http.Put | http.Patch | http.Delete -> request.set_method(request, method)
      _ -> request
    })
  }
  |> result.unwrap(request)
}
