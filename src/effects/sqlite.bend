# Trusted SQLite boundary (BND-38), outside the proofs. src/sqlite.bend is
# the API; sqlite.md beside this file says what the effect does.
#
# One effect, sqlite_call, carries every operation, chosen by `op`. The
# native build loads libsqlite3 with dlopen at the first open, and the JS
# twin loads the same library through bun:ffi, so both run the same SQLite.
# Bound parameters arrive as one string in the wire format of
# src/data/sqlite.bend; the effect binds each one with sqlite3_bind_*, so no
# parameter is ever part of the SQL text. Failures carry SQLite's extended
# result code and message, or one of the effect's own (sqlite.md lists them).
import Base

# A column value as SQLite stores it; src/sqlite.bend turns each into a
# Sqlite.Value. Integers are exact decimal text in the signed 64-bit range;
# reals are the shortest decimal that reads back as the same double, written
# as JavaScript's Number.prototype.toString writes it. The proofs may not
# import this file, so the pure module declares its own value type.
type Cell is Data:
  CellNull{}
  CellInteger{text: String}
  CellReal{text: String}
  CellText{value: String}
  CellBlob{bytes: List<&2, U32>}

# Ran's changes are the rows the statement changed (SQLite's total-changes
# delta, so triggers and foreign-key actions count) and rowid the
# connection's last insert rowid. The native build flattens a field whose
# type has one constructor into its parent and packs a lone U32 field into
# the term, so these constructors avoid both: sqlite.c builds each with
# exactly the fields written.
type Reply is Data:
  Handle{first: U32, second: U32}
  Finished{}
  Ran{columns: List<&2, String>, rows: List<&2, List<&2, Cell>>, changes: Nat, rowid: String}

# op 0 open: text1 path, mode 0 read-write-create / 1 read-write / 2
#   read-only, limit busy timeout in ms. Handle{slot, gen}.
# op 1 close: slot, gen. Finished.
# op 2 prepare: slot, gen, text1 SQL. Handle{index, sgen}.
# op 3 finalize: slot, gen, index, sgen. Finished.
# op 4 query: slot, gen, token, index and sgen (index 0 runs text1 once),
#   mode 0 run / 1 all / 2 get, limit (most rows for all), max_bytes (most
#   bytes of cell data in the result) and max_cell (most bytes in one text or
#   blob cell) for all and get, text2 params. Ran.
# op 5 exec: slot, gen, token, text1 script with no parameters. Finished.
#   Every operation but op 6 and op 7 refuses a transaction-control
#   statement (BEGIN, COMMIT, END, ROLLBACK, SAVEPOINT, RELEASE) before it
#   runs.
# op 6 begin: slot, gen, mode 0 deferred / 1 immediate / 2 exclusive.
#   Handle{token, 0}.
# op 7 end: slot, gen, token, mode 1 commit / 0 rollback. Finished.
def sqlite_call(op: U32, slot: U32, gen: U32, token: U32, index: U32, sgen: U32, mode: U32, limit: U32, max_bytes: U32, max_cell: U32, text1: String, text2: String) -> IO(Result<&1, &1, U32 & String, Reply>):
  import "./sqlite.c"
  import "./sqlite.js"
