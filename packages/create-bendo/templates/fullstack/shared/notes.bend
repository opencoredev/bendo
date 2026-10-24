# Note rules shared by the server and the browser. main.bend builds its body
# schema from max_length, and src/ imports this file through vite-plugin-bendo,
# so the form counts characters with the same code the server runs.
import Base

def max_length() -> Nat:
  140n

# Length in code points, as the server's string schema counts it.
def length(text: String) -> Nat:
  String.length(text)

def fits(text: String) -> Bool:
  +n = String.length(text)
  Nat.is_le(1n, n) && Nat.is_le(n, max_length())
