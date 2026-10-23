# Thin entropy shell. No PRNG fallback and no IO.try process exit.
import Base

def RandomError() -> Type:
  U32 & String

def push(acc: List<&2, U32>, result: Result<&1, &1, RandomError(), U32>) -> Result<&1, &1, RandomError(), List<&2, U32>>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{word}:
      Done{U32.and(word, 255) <> acc}

# Linux getrandom failures arrive as Fail{(errno, strerror)}. macOS
# arc4random_buf has no recoverable failure return. The JS twin catches
# WebCrypto exceptions (including missing crypto) and returns EIO (5).
# Propagate that exact error; discard any bytes already collected.
def random_go(n: Nat, result: Result<&1, &1, RandomError(), List<&2, U32>>) -> IO(Result<&1, &1, RandomError(), List<&2, U32>>):
  match n:
    case 0n:
      match result:
        case Fail{error}:
          IO.pure(Result<&1, &1, RandomError(), List<&2, U32>>, Fail{error})
        case Done{acc}:
          IO.pure(Result<&1, &1, RandomError(), List<&2, U32>>, Done{List.reverse(&2, U32, acc)})
    case 1n+p:
      match result:
        case Fail{error}:
          IO.pure(Result<&1, &1, RandomError(), List<&2, U32>>, Fail{error})
        case Done{acc}:
          do IO<Result<&1, &1, RandomError(), List<&2, U32>>>:
            word : Result<&1, &1, RandomError(), U32> <- IO.random_u32()
            random_go(p, push(acc, word))

# One random word per byte (low octet); n=0 performs no entropy effect.
def random_bytes(n: Nat) -> IO(Result<&1, &1, RandomError(), List<&2, U32>>):
  random_go(n, Done{[]})
