---
title: Validation
description: Route schemas as data, what happens to a request that fails them, and how the browser runs the same check.
---

# Validation

A route can declare what it accepts. Bendo then checks each request before
your handler runs, answers bad requests with a list of every problem, and gives
the handler decoded values so it never parses input itself.

## Schemas are data

A schema is a Bend value describing a JSON shape, built from constructors in
`src/data/schema.bend`:

```python
def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}}], S.Strict{}}
```

This accepts an object with a `title` of 1 to 80 characters and an optional
`done` boolean that defaults to `false`. `S.Strict{}` rejects any other key.

Because a schema is data, like a route, it can sit in the route table. Attach
schemas to a route for any of five slots, path params, query, headers, body and
response:

```python
B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())]))
```

Serve the app with the entrypoints in `src/validated.bend` (`V.serve` instead
of `B.serve`). The plain `B.` entrypoints leave the decoder out to keep apps
without schemas small, and refuse to start if a route declares one.

## A request that fails

Every slot is checked, and the rejection lists every failing path. Posting
`{"title":""}` to the route above answers 422:

```json
{"error":"Unprocessable Content","status":422,"errors":[{"path":["body","title"],"code":"constraint","message":"value does not satisfy scalar checks"}]}
```

The status says which slot failed: 400 for params, query or headers, 415 for a
body that is not JSON, 400 for malformed JSON, and 422 for a body that does not
match its schema. The handler and the `before_handle` hooks never run for a
rejected request.

## A request that passes

The handler reads the decoded values with `B.valid_body(c)`,
`B.valid_query(c)` and their siblings. Defaults are filled in and undeclared
keys are stripped or rejected, as the schema says. Text slots (params, query,
headers) are coerced, so `?page=2` decodes as the integer 2. The JSON body is
not: `"done":"true"` is a type mismatch for a boolean.

A response schema checks your own output. In development a violating response
becomes a 500; in production it is sent and logged.

## The same check in the browser

The decoder is pure Bend, so it compiles to native code for the server and to
JavaScript for a browser. `bendo build --shared` turns a Bend file of schemas
and checks into an ES module with TypeScript declarations. A form can then
reject bad input with the exact code the server will run. The
[todo example](../examples.md#todo) does this, and
[share Bend code with JavaScript](../shared.md) shows how.

Compiled apps also print their schemas as JSON Schema in the
[route manifest](../manifest.md#route-schemas), which is where the
[typed client](../client.md) and [OpenAPI export](../openapi.md) get them.

## Guarantees

The validation laws state that a request is admitted exactly when every
declared slot decodes, that a rejection lists exactly the slots' errors, and
that the handler runs only for admitted requests. See [route validation](../validation.md#guarantees)
and the [data laws](../laws/data.md).

## Read on

- [Route validation](../validation.md) is the full reference.
- [Schemas](../data/schema.md) lists every schema constructor.
