# The chat's pure state: the fixed rooms, the input rules, and the lobby that
# one B.Store holds, with each room's recent lines and who is in it. main.bend
# is the IO shell around it.
import Base
import ../../src/data/json.bend as J

def rooms() -> List<&2, String>:
  ["general", "random", "bend"]

def known_go(rs: List<&2, String>, +room: String) -> Bool:
  match rs:
    case Nil{}: False{}
    case r <> rest: String.eq(r, room) || known_go(rest, room)

def known(room: String) -> Bool:
  known_go(rooms(), room)

# Input rules. Names and messages are trimmed first, then counted in code
# points. Control characters are refused, except tab and newline in a message.
def visible(+c: U32) -> Bool:
  (c >= 32 : U32) && U32.is_ne(c, 127)

def text_char(+c: U32) -> Bool:
  visible(c) || U32.is_eq(c, 10) || U32.is_eq(c, 9)

def name_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: visible(c) && name_chars(t)

def text_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: text_char(c) && text_chars(t)

def within(+n: Nat, max: Nat) -> Bool:
  Nat.is_gt(n, 0n) && Nat.is_le(n, max)

def max_name() -> Nat:
  24n

def max_text() -> Nat:
  2000n

def keep_if(s: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{s}
    case False{}: None{}

def name_of(+trimmed: String) -> Maybe<&2, String>:
  keep_if(trimmed, within(String.length(trimmed), max_name()) && name_chars(trimmed))

def text_of(+trimmed: String) -> Maybe<&2, String>:
  keep_if(trimmed, within(String.length(trimmed), max_text()) && text_chars(trimmed))

# The display name from `?name=`, trimmed, or None if it breaks the rules.
def clean_name(name: Maybe<&2, String>) -> Maybe<&2, String>:
  match name:
    case None{}: None{}
    case Some{n}: name_of(String.trim(n))

def clean_text(text: String) -> Maybe<&2, String>:
  text_of(String.trim(text))

type Act is Data:
  Said{text: String}
  Arrived{}
  Departed{}

# One line of a room's history. `seq` counts every line in the lobby, so a
# client can merge its welcome snapshot with live lines and drop duplicates.
# `id` is the connection's hub ID; `at` is wall-clock milliseconds.
type Line is Data:
  Line{seq: Nat, room: String, id: Nat, name: String, kind: Act, at: Nat}

type Person is Data:
  Person{id: Nat, room: String, name: String}

# Lines are newest first, at most history_cap() per room.
type Lobby is Data:
  Lobby{next: Nat, lines: List<&2, Line>, people: List<&2, Person>}

def lobby() -> Lobby:
  Lobby{1n, [], []}

def history_cap() -> Nat:
  100n

def room_of(line: Line) -> String:
  Line{seq, room, id, name, kind, at} = line
  room

def keeps(same: Bool, left: Nat) -> Bool:
  match same left:
    case True{} 0n: False{}
    case True{} 1n+k: True{}
    case False{} _: True{}

def spend(same: Bool, left: Nat) -> Nat:
  match same left:
    case True{} 0n: 0n
    case True{} 1n+k: k
    case False{} n: n

def prepend(line: Line, keep: Bool, rest: List<&2, Line>) -> List<&2, Line>:
  match keep:
    case True{}: line <> rest
    case False{}: rest

# Keeps the newest `left` lines of `room` and every line of the other rooms.
def trim(lines: List<&2, Line>, +room: String, left: Nat) -> List<&2, Line>:
  match lines:
    case Nil{}: []
    case +line <> rest:
      +same = String.eq(room_of(line), room)
      +n = left
      prepend(line, keeps(same, n), trim(rest, room, spend(same, n)))

def record(lobby: Lobby, +room: String, id: Nat, name: String, kind: Act, at: Nat) -> Lobby:
  Lobby{+next, lines, people} = lobby
  Lobby{1n+next, trim(Line{next, room, id, name, kind, at} <> lines, room, history_cap()), people}

def drop_if(person: Person, gone: Bool, rest: List<&2, Person>) -> List<&2, Person>:
  match gone:
    case True{}: rest
    case False{}: person <> rest

def without(people: List<&2, Person>, +id: Nat) -> List<&2, Person>:
  match people:
    case Nil{}: []
    case Person{+pid, room, name} <> rest:
      drop_if(Person{pid, room, name}, Nat.is_eq(pid, id), without(rest, id))

# A connection takes a seat in `room` and the room hears about it.
def enter(lobby: Lobby, +id: Nat, +room: String, +name: String, at: Nat) -> Lobby:
  Lobby{next, lines, people} = lobby
  record(Lobby{next, lines, Person{id, room, name} <> people}, room, id, name, Arrived{}, at)

def say(lobby: Lobby, id: Nat, room: String, name: String, text: String, at: Nat) -> Lobby:
  record(lobby, room, id, name, Said{text}, at)

# The connection leaves the room's people, and the room hears about it.
def exit(lobby: Lobby, +id: Nat, room: String, name: String, at: Nat) -> Lobby:
  Lobby{next, lines, people} = lobby
  record(Lobby{next, lines, without(people, id)}, room, id, name, Departed{}, at)

def add_line(line: Line, same: Bool, acc: List<&2, Line>) -> List<&2, Line>:
  match same:
    case True{}: line <> acc
    case False{}: acc

# The room's lines, oldest first.
def room_lines(lines: List<&2, Line>, +room: String, acc: List<&2, Line>) -> List<&2, Line>:
  match lines:
    case Nil{}: acc
    case +line <> rest: room_lines(rest, room, add_line(line, String.eq(room_of(line), room), acc))

def person_room(person: Person) -> String:
  Person{id, room, name} = person
  room

def add_person(person: Person, same: Bool, rest: List<&2, Person>) -> List<&2, Person>:
  match same:
    case True{}: person <> rest
    case False{}: rest

def room_people(people: List<&2, Person>, +room: String) -> List<&2, Person>:
  match people:
    case Nil{}: []
    case +person <> rest: add_person(person, String.eq(person_room(person), room), room_people(rest, room))

def online(people: List<&2, Person>, room: String) -> Nat:
  List.length(&2, Person, room_people(people, room))

# JSON events. The client reads `type` first.
def num(n: Nat) -> J.Json:
  J.JNumber{Nat.show(n)}

def str(s: String) -> J.Json:
  J.JString{s}

def field(key: String, value: J.Json) -> J.Field:
  J.Field{key, value}

def kind_name(kind: Act) -> String:
  match kind:
    case Said{text}: "said"
    case Arrived{}: "joined"
    case Departed{}: "left"

def with_text(kind: Act, fields: List<&2, J.Field>) -> List<&2, J.Field>:
  match kind:
    case Said{text}: field("text", str(text)) <> fields
    case _: fields

def line_json(line: Line) -> J.Json:
  Line{seq, room, id, name, +kind, at} = line
  J.JObject{field("type", str(kind_name(kind))) <> field("seq", num(seq)) <> field("room", str(room)) <> field("id", num(id)) <> field("name", str(name)) <> field("at", num(at)) <> with_text(kind, [])}

def lines_json(lines: List<&2, Line>) -> List<&2, J.Json>:
  match lines:
    case Nil{}: []
    case line <> rest: line_json(line) <> lines_json(rest)

def person_json(person: Person) -> J.Json:
  Person{id, room, name} = person
  J.JObject{[field("id", num(id)), field("name", str(name))]}

def people_json(people: List<&2, Person>) -> List<&2, J.Json>:
  match people:
    case Nil{}: []
    case person <> rest: person_json(person) <> people_json(rest)

def counts_json(rs: List<&2, String>, +people: List<&2, Person>) -> List<&2, J.Json>:
  match rs:
    case Nil{}: []
    case +r <> rest: J.JObject{[field("id", str(r)), field("online", num(online(people, r)))]} <> counts_json(rest, people)

def counts(lobby: Lobby) -> J.Json:
  Lobby{next, lines, people} = lobby
  J.JArray{counts_json(rooms(), people)}

def encoded(written: Result<&2, &2, J.Error, String>) -> String:
  match written:
    case Done{s}: s
    case Fail{e}: "{\"type\":\"error\",\"reason\":\"encoding failed\"}"

def encode(value: J.Json) -> String:
  encoded(J.stringify(value))

# GET /api/rooms: {"rooms":[{"id","online"}]}.
def rooms_json(lobby: Lobby) -> J.Json:
  J.JObject{[field("rooms", counts(lobby))]}

# Sent on the presence topic whenever someone enters or leaves any room.
def presence(lobby: Lobby) -> String:
  encode(J.JObject{[field("type", str("presence")), field("rooms", counts(lobby))]})

# The largest frame the server sends or accepts, in bytes (session() in
# main.bend). A message is at most 2000 characters, so 16 KiB covers any
# UTF-8 spelling of one, quotes and backslashes escaped.
def frame_limit() -> U32:
  16384

def width(one: Bool, two: Bool, three: Bool) -> U32:
  match one two three:
    case True{} _ _: 1
    case False{} True{} _: 2
    case False{} False{} True{}: 3
    case False{} False{} False{}: 4

def char_bytes(+c: U32) -> U32:
  width((c < 128 : U32), (c < 2048 : U32), (c < 65536 : U32))

# The UTF-8 length of `s`, plus `n`. Encoded JSON holds no surrogates (the
# writer refuses them), so every char is one scalar.
def utf8_bytes(s: String, n: U32) -> U32:
  match s:
    case SNil{}: n
    case SCon{Chr{c}, t}: utf8_bytes(t, (n + char_bytes(c) : U32))

# A line's bytes in the welcome's history, with the comma before it.
def line_cost(line: Line) -> U32:
  utf8_bytes(encode(line_json(line)), 1)

def left(fits: Bool, budget: U32, cost: U32) -> U32:
  match fits:
    case True{}: (budget - cost : U32)
    case False{}: 0

# Takes lines, newest first, while their bytes fit the budget, and returns
# them oldest first. The first line that does not fit spends the budget, so
# no older line is taken and the history has no gaps.
def fit(lines: List<&2, Line>, budget: U32, acc: List<&2, Line>) -> List<&2, Line>:
  match lines:
    case Nil{}: acc
    case +line <> rest:
      +cost = line_cost(line)
      +b = budget
      +fits = (cost <= b : U32)
      fit(rest, left(fits, b, cost), add_line(line, fits, acc))

def shape(+room: String, id: Nat, next: Nat, +people: List<&2, Person>, history: List<&2, Line>, truncated: Bool) -> J.Json:
  J.JObject{[field("type", str("welcome")), field("room", str(room)), field("you", num(id)), field("next", num(next)), field("truncated", J.JBool{truncated}), field("people", J.JArray{people_json(room_people(people, room))}), field("history", J.JArray{lines_json(history)}), field("rooms", J.JArray{counts_json(rooms(), people)})]}

def fitted(fits: Bool, +room: String, id: Nat, next: Nat, +people: List<&2, Person>, +lines: List<&2, Line>, base: U32) -> Maybe<&2, String>:
  match fits:
    case False{}: None{}
    case True{}:
      +kept = fit(lines, (frame_limit() - base : U32), [])
      Some{encode(shape(room, id, next, people, kept, Nat.is_lt(List.length(&2, Line, kept), List.length(&2, Line, lines))))}

# The first frame a connection gets: who it is, who is in the room, the
# room's history, the room counts, and `next`, the first seq the snapshot
# does not include. The history is the room's newest lines that fit in
# frame_limit() bytes; `truncated` says older ones were left out. None if the
# rest of the welcome alone is too big, which takes well over a hundred
# people in the room.
def welcome(lobby: Lobby, +room: String, +id: Nat) -> Maybe<&2, String>:
  Lobby{+next, lines, +people} = lobby
  +base = utf8_bytes(encode(shape(room, id, next, people, [], False{})), 0)
  fitted((base <= frame_limit() : U32), room, id, next, people, List.reverse(&2, Line, room_lines(lines, room, [])), base)

def head_text(lines: List<&2, Line>) -> String:
  match lines:
    case Nil{}: encode(J.JObject{[field("type", str("error")), field("reason", str("no line"))]})
    case line <> rest: encode(line_json(line))

# The line `record` just added, as a JSON event.
def newest(lobby: Lobby) -> String:
  Lobby{next, lines, people} = lobby
  head_text(lines)

def error(reason: String) -> String:
  encode(J.JObject{[field("type", str("error")), field("reason", str(reason))]})
