# Hello from Bendo. Run: bend examples/hello/main.bend -o hello && ./hello
import Base
import ../../src/http.bend as Http
import ../../src/serve.bend as Serve

def app(req: String) -> String:
  Http.text("Hello from Bendo! You asked for " ++ Http.path_of(req))

def main() -> IO(Unit):
  Serve.serve(~app, 8787)
