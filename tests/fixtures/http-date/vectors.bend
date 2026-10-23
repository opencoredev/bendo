import Base
import ../../../src/http/date.bend as Date

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Date.format_imf(0n))
    IO.print(Date.format_imf(784111777n))
    IO.print(Date.format_imf(951782400n))
    IO.print(Date.format_imf(4107542400n))
    IO.print(Date.format_imf(Date.max_seconds()))
