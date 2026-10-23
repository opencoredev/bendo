import Base
import ../src/router/spec.bend as S
import ../src/router/pattern.bend as P

def result_text(result: Result<&2, &2, S.BuildError, S.Table(U32)>) -> String:
  match result:
    case Fail{S.BuildError{index, source, error}}:
      Nat.show(index) ++ ":" ++ source ++ ":" ++ P.error_message(error)
    case Done{table}:
      "ok:" ++ Nat.show(List.length(&2, S.Route<U32>, table))

def hit_text(hit: Maybe<&2, S.Match<U32>>) -> String:
  match hit:
    case None{}:
      "none"
    case Some{S.Match{index, tag, params}}:
      Nat.show(index) ++ ":" ++ U32.show(tag)

def compiled(result: Result<&2, &2, S.BuildError, S.Table(U32)>) -> String:
  match result:
    case Fail{error}:
      "error"
    case Done{+table}:
      hit_text(S.route(U32, table, "/same")) ++ "," ++ hit_text(S.route(U32, table, "/other"))

type Payload is Data:
  Payload{label: String, code: Nat}

def payload_hit(hit: Maybe<&2, S.Match<Payload>>) -> String:
  match hit:
    case None{}:
      "none"
    case Some{S.Match{index, Payload{label, code}, params}}:
      Nat.show(index) ++ ":" ++ label ++ ":" ++ Nat.show(code)

def payload_table(result: Result<&2, &2, S.BuildError, S.Table(Payload)>) -> String:
  match result:
    case Fail{error}:
      "error"
    case Done{+table}:
      payload_hit(S.route(Payload, table, "/users/new")) ++ "," ++ payload_hit(S.route(Payload, table, "/files/fixed")) ++ "," ++ payload_hit(S.route(Payload, table, "/users/again"))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(result_text(S.build_table(U32, [])))
    IO.print(result_text(S.build_table(U32, [S.Registration{"/ok", 1}, S.Registration{"bad", 2}, S.Registration{"also-bad", 3}])))
    IO.print(result_text(S.build_table(U32, [S.Registration{"/:x{nope}", 1}])))
    IO.print(compiled(S.build_table(U32, [S.Registration{"/same", 11}, S.Registration{"/same", 22}, S.Registration{"/other", 33}])))
    IO.print(hit_text(S.route(U32, [], "/")))
    IO.print(payload_table(S.build_table(Payload, [
      S.Registration{"/users/:name", Payload{"parameter", 71n}},
      S.Registration{"/users/new", Payload{"static", 72n}},
      S.Registration{"/files/*rest", Payload{"wildcard", 73n}},
      S.Registration{"/files/fixed", Payload{"fixed", 74n}}
    ])))
