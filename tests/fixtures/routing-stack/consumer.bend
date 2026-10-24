# BND-84: the .mjs build of every request-path helper, called by
# tests/routing-stack.test.ts with 65536-character input.
import Base
import ./common.bend as R

def encode(s: String) -> String:
  R.encode(s)

def decode(s: String) -> String:
  R.decode(s)

def scalars(s: String) -> String:
  R.scalars(s)

def digits(s: String) -> String:
  R.digits(s)

def slug(s: String) -> String:
  R.slug(s)

def uuid(s: String) -> String:
  R.uuid(s)

def letters(s: String) -> String:
  R.letters(s)

def segments(s: String) -> String:
  R.segments(s)

def wildcard(s: String) -> String:
  R.wildcard(s)

def route(pattern: String, path: String) -> String:
  R.route(pattern, path)

def resolve(raw: String) -> String:
  R.resolve(raw)

def route_options(pattern: String, path: String) -> String:
  R.route_options(pattern, path)
