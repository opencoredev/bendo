---
title: Proofs
description: What Bendo's laws are, how a law and its proof fit together, and how to check them yourself.
---

# Proofs

Tests check the inputs someone thought of. Bendo's core also carries **laws**:
statements about every input, each one proven and machine-checked. A law about
the router holds for every route table and every path, not only for the ones in
a test file.

## A law and its proof

Laws live in `LAWS.bend` and the `proof/*-laws.bend` files it imports. Each
law is a claim written in Bend itself:

```python
# LAW: a text response is a head with no blank line in it, then a blank
# line, then the body. So the first blank line in the response is the one
# that ends the head, and a client that cuts there reads the body back.
law text_body_after_blank:
  for +body: String
  exs head: String
  {String.contains(head, "\r\n\r\n") == False{} : Bool} & {head ++ ("\r\n\r\n" ++ body) == Http.text(body) : String}
```

`for` reads "for every", and `exs` reads "there exists". This law says that
for every body, `Http.text(body)` is some head without a blank line, then a
blank line, then that body.

`PROOF.bend` proves each law with a def of the same name. In Bend a proof is
an ordinary function whose type is the claim, so the type checker checks it:

```python
def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))
```

This one names the head and shows that both equations compute (`{==}`). Laws
about every route table or every request take induction and longer proofs, but
they are checked the same way.

## Who writes what

Humans own the laws. Agents and contributors may add laws and write proofs, but
never delete or weaken a law to make a proof pass. A stuck proof is a question
for a person. This keeps the claims honest: the proof can change, the promise
cannot quietly shrink.

## Check them yourself

From a clone of the repository, with Lean installed through elan at the version
in `lean-toolchain` (the [agent guide](../../AGENTS.md) has the setup):

```sh
bun run prove
```

This runs `bend PROOF.bend --verdict`. Bend checks every proof, then checks
them again with a small kernel that itself has a proof in Lean. It prints
`ALL PROOFS CHECK` only when every proof passes both checks and none relies on
unsafe or foreign code. `bendo prove` runs the same check with readable error
output.

## What the laws cover

The laws are about pure functions: parsing, routing, middleware composition,
JSON, forms, cookies, schemas, validation, JWT checks, WebSocket frames and
more. IO, such as the accept loop, sockets and timers, sits in thin shells
that integration tests exercise against compiled servers instead. Many laws
compare Bendo's code with a separate specification written from the RFC, and a
law is only as strong as that specification is independent.

[The laws in plain words](../laws/README.md) lists every law with one sentence
on what it guarantees you, and says what the laws do not cover.

## Read on

- [The laws in plain words](../laws/README.md), grouped by area.
- [Routing laws](../laws/routing.md), a good first section to read.
- [Equivalence laws](../laws/equivalences.md) explain how the fast paths stay
  equal to the proven definitions.
