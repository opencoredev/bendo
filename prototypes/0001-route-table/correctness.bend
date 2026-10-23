import Base
import ./shapes.bend as S

def first(nonce: U32) -> U32:
  11

def second(nonce: U32) -> U32:
  22

def last(path: String, nonce: U32) -> U32:
  S.chain(~second, ~S.missing, "/same", path, nonce)

def chained(path: String, nonce: U32) -> U32:
  S.chain(~first, ~last, "/same", path, nonce)

def listed(path: String) -> U32:
  S.template_list(~[S.FnRoute{"/same", first}, S.FnRoute{"/same", second}], path, 0)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("duplicate first match list=" ++ U32.show(listed("/same")))
    IO.print("duplicate first match data=" ++ U32.show(S.data_walk([S.Route{"/same", 11}, S.Route{"/same", 22}], "/same")))
    IO.print("duplicate first match chain=" ++ U32.show(chained("/same", 0)))
    IO.print("miss list=" ++ U32.show(listed("/absent")))
    IO.print("miss data=" ++ U32.show(S.data_walk([S.Route{"/same", 11}], "/absent")))
    IO.print("miss chain=" ++ U32.show(chained("/absent", 0)))
