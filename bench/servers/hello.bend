import Base
import ../../src/http.bend as Http
import ../../src/serve.bend as Serve

def app(req: String) -> String:
  Http.text("Hello, world!")

def main() -> IO(Unit):
  Serve.serve(~app, 8787)
