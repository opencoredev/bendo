---
title: Routing
description: Why Bendo routes map patterns to tags, how the first match wins, and where 404 and 405 come from.
---

# Routing

In Hono you register a path and a handler function. In Bendo you register a
path and a **tag**, a value of a type your app defines, and one dispatcher
turns the tag into a response.

```python
type Tag is Data:
  ListTodos{}
  GetTodo{}
  CreateTodo{}

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.get(Tag, "/todos", ListTodos{}),
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.post(Tag, "/todos", CreateTodo{})]))
```

The dispatcher matches the tag and calls an ordinary top-level def for each
route:

```python
def dispatch(tag: Tag, ctx: B.Ctx, env: Env) -> IO(B.Res):
  match tag:
    case ListTodos{}:
      list_todos(ctx, env)
    case GetTodo{}:
      get_todo(ctx, env)
    case CreateTodo{}:
      create_todo(ctx, env)
```

`ready` handles the result of `B.routes` and calls `B.serve`, as in the
[quick start](../getting-started.md#3-create-an-app).

## Why tags instead of functions

Bend cannot copy a function value at run time, and a server needs its route
table on every connection. So the table holds only copyable data: compiled
patterns and your tags. Every connection gets its own copy, and the router
returns a tag and the decoded params. The dispatcher is a template (`~dispatch`)
that Bend inlines at compile time, so it can run for any number of requests.

The same data has other readers. The [route manifest](../manifest.md) prints
it as JSON, `bendo gen` turns it into [TypeScript types](../route-types.md),
and the laws reason about it directly. [Decision 0001](../decisions/0001-route-table.md)
records the trade-off: the tag type and the `match` repeat the route list once.

## Patterns

A pattern is static segments plus captures. The common forms:

| Pattern | Matches | Captures |
| --- | --- | --- |
| `/todos` | `/todos` only | none |
| `/todos/:id` | `/todos/42`, `/todos/abc` | `id` |
| `/todos/:id{int}` | `/todos/42`, not `/todos/abc` | `id` |
| `/v1/:version?` | `/v1` and `/v1/2` | `version` when present |
| `/files/*path` | `/files`, `/files/a/b.txt` | `path` |

Read captures in a handler with `B.param(c, "id")`. Matching is exact: case
sensitive, with no trailing-slash folding. [Route patterns](../router-patterns.md)
has the full syntax, including `{uuid}`, character classes and spans.

## The first match wins

Bendo tries routes in registration order and takes the first that matches.
It does not rank by specificity. If you register `/users/:name` before
`/users/new`, a request for `/users/new` reaches the `:name` route. Put the
more specific route first. A capture that fails its constraint, such as
`{int}`, counts as a miss, and the next route is tried.

The default router is a trie, which skips routes whose leading static segments
cannot match. It is proven to return exactly what the simple first-match
router returns, for every table and path. See the [trie router](../router-trie.md).

## 404, 405 and HEAD

When no pattern matches the path, the answer is `404 Not Found`. When a pattern
matches but not for this method, the answer is `405 Method Not Allowed`, with an
`Allow` header listing every method that would match. A GET route also answers
HEAD with the same headers and no body. [Route by HTTP method](../router-methods.md)
covers `B.on`, `B.all` and extension methods.

## Compose route lists

A route list is a plain Bend list, so you can build it from functions.
`B.route(Tag, "/api/v1/items", items())` mounts a sub-list under a prefix, and
`B.group` does the same while attaching hooks. All of it flattens into one
table. See [compose route lists](../router-compose.md).

## Guarantees

The [routing laws](../laws/routing.md) state, among others, that pattern
matching agrees with an independent specification for every pattern and path,
that the router returns the first matching registration, and that the trie is
a drop-in replacement for it.
