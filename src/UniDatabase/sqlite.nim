## SPDX-License-Identifier: Apache-2.0
import std/os
import UniDatabase/sqlite_raw

type
  DatabaseError* = object of IOError
  StepResult* = enum
    rowAvailable
    statementDone
  SqliteCapability* = enum
    preparedStatements
    transactions
    writeAheadLog
    fullTextSearch5
  Connection* = object
    handle: ptr Sqlite3
  Statement* = object
    handle: ptr SqliteStmt
    connection: ptr Sqlite3

proc `=copy`(destination: var Connection; source: Connection) {.error:
  "a Connection owns a SQLite handle and cannot be copied: pass it, or open " &
  "another one".}
proc `=copy`(destination: var Statement; source: Statement) {.error:
  "a Statement owns a SQLite handle and cannot be copied: pass it, or prepare " &
  "another one".}
  ## Both types are value objects holding a raw SQLite pointer, and `close` and
  ## `finalize` clear only the receiver's copy. A duplicate would keep a pointer
  ## to memory SQLite has freed, and finalize it a second time. Refused by the
  ## compiler rather than left to a caller to avoid: moves still work, which is
  ## every legitimate use.

const SqliteCapabilities* = {preparedStatements, transactions}
  ## What the API offers on any SQLite. WAL and FTS5 are compile-time options of
  ## the linked library, so `capabilities` asks for them rather than declaring
  ## them here.

proc fail(connection: Connection; operation: string) {.noreturn.} =
  let detail = if connection.handle == nil: "closed connection" else: $sqlite3_errmsg(
      connection.handle)
  raise newException(DatabaseError, operation & ": " & detail)

proc requireLive(statement: Statement; operation: string) =
  ## `finalize` sets the handle to nil and is idempotent by design, so a caller
  ## can reach any Statement procedure with a finalized one. Without this the
  ## answer came from the linked SQLite's own tolerance for a null pointer, and
  ## measured against the system SQLite that was four silent successes out of
  ## seven: `columnInt64` returned 0 and `columnText` "" for a row that held 42
  ## and "reel", while `reset` and `clearBindings` reported success. The other
  ## three raised, `step` with "not an error" as its reason.
  ##
  ## A wrong answer that looks like an answer is worse than a refusal, and the
  ## behaviour must not depend on which SQLite the binary happened to link. The
  ## Connection procedures already refuse this way.
  if statement.handle == nil:
    raise newException(DatabaseError, operation & ": statement already finalized")

proc openSqlite*(path: string; createParent = true): Connection =
  let parent = path.parentDir
  if createParent and parent.len > 0 and not dirExists(parent): createDir(parent)
  if sqlite3_open_v2(path, addr result.handle,
      SqliteOpenReadWrite or SqliteOpenCreate, nil) != SqliteOk:
    let detail = if result.handle == nil: "unable to open database" else: $sqlite3_errmsg(result.handle)
    if result.handle != nil: discard sqlite3_close(result.handle)
    result.handle = nil
    raise newException(DatabaseError, "opening SQLite: " & detail)

proc isOpen*(connection: Connection): bool = connection.handle != nil

proc capabilities*(connection: Connection): set[SqliteCapability] =
  if not connection.isOpen: connection.fail("reading SQLite capabilities")
  result = SqliteCapabilities
  # Both are asked of the linked library. A SQLite built with SQLITE_OMIT_WAL
  # has no write-ahead log at all, and announcing one would send a caller into
  # `PRAGMA journal_mode=WAL` that silently does not take.
  if sqlite3_compileoption_used("OMIT_WAL") == 0:
    result.incl(writeAheadLog)
  if sqlite3_compileoption_used("ENABLE_FTS5") != 0:
    result.incl(fullTextSearch5)

proc close*(connection: var Connection) =
  if connection.handle != nil:
    if sqlite3_close(connection.handle) != SqliteOk:
      connection.fail("closing SQLite")
    connection.handle = nil

proc executeScript*(connection: Connection; sql: string) =
  ## Every statement in `sql`, in order, with no parameters. This is SQLite's
  ## own `sqlite3_exec`: a semicolon-separated script runs whole, which is what
  ## a schema or a migration is. Values must never be formatted into it -- use
  ## `execute` with `?` placeholders for anything a caller supplies.
  if not connection.isOpen: connection.fail("executing SQL")
  var message: cstring
  if sqlite3_exec(connection.handle, sql, nil, nil, addr message) != SqliteOk:
    let detail = if message == nil: $sqlite3_errmsg(
        connection.handle) else: $message
    if message != nil: sqlite3_free(message)
    raise newException(DatabaseError, detail)

proc prepare*(connection: Connection; sql: string): Statement =
  if not connection.isOpen: connection.fail("preparing SQL")
  result.connection = connection.handle
  if sqlite3_prepare_v2(connection.handle, sql, -1, addr result.handle, nil) != SqliteOk:
    connection.fail("preparing SQL")

proc finalize*(statement: var Statement) =
  if statement.handle != nil:
    # The handle is cleared first, on purpose: sqlite3_finalize deallocates the
    # statement whether or not it reports an error, so raising before this line
    # would leave a pointer to freed memory behind and `isLive` would agree.
    let handle = statement.handle
    statement.handle = nil
    if sqlite3_finalize(handle) != SqliteOk:
      raise newException(DatabaseError, "finalizing SQLite statement")

proc isLive*(statement: Statement): bool =
  ## False once `finalize` has run. Every other Statement procedure raises
  ## rather than act on one, so this is for a caller who wants to ask first.
  statement.handle != nil

proc bindText*(statement: Statement; index: int; value: string) =
  statement.requireLive("binding SQLite text")
  if sqlite3_bind_text(statement.handle, index.cint, value, value.len.cint,
      SqliteTransient) != SqliteOk:
    raise newException(DatabaseError, "binding SQLite text")

proc bindInt64*(statement: Statement; index: int; value: int64) =
  statement.requireLive("binding SQLite integer")
  if sqlite3_bind_int64(statement.handle, index.cint, value) != SqliteOk:
    raise newException(DatabaseError, "binding SQLite integer")

proc step*(statement: Statement): StepResult =
  statement.requireLive("stepping SQLite statement")
  case sqlite3_step(statement.handle)
  of SqliteRow: rowAvailable
  of SqliteDone: statementDone
  else:
    let detail = if statement.connection == nil: "unknown error" else:
      $sqlite3_errmsg(statement.connection)
    raise newException(DatabaseError, "stepping SQLite statement: " & detail)

proc reset*(statement: Statement) =
  statement.requireLive("resetting SQLite statement")
  if sqlite3_reset(statement.handle) != SqliteOk:
    raise newException(DatabaseError, "resetting SQLite statement")

proc clearBindings*(statement: Statement) =
  statement.requireLive("clearing SQLite bindings")
  if sqlite3_clear_bindings(statement.handle) != SqliteOk:
    raise newException(DatabaseError, "clearing SQLite bindings")

proc columnText*(statement: Statement; index: int): string =
  statement.requireLive("reading a SQLite text column")
  let value = sqlite3_column_text(statement.handle, index.cint)
  let length = sqlite3_column_bytes(statement.handle, index.cint)
  if value != nil and length > 0:
    result = newString(length)
    copyMem(addr result[0], value, length)

proc columnInt64*(statement: Statement; index: int): int64 =
  statement.requireLive("reading a SQLite integer column")
  sqlite3_column_int64(statement.handle, index.cint)

proc scalarInt64*(connection: Connection; sql: string): int64 =
  var statement = connection.prepare(sql)
  defer: statement.finalize
  if statement.step != rowAvailable:
    raise newException(DatabaseError, "scalar query returned no row")
  statement.columnInt64(0)

# Literal statements with nothing bound into them, so `executeScript` -- which
# is also the only one declared this early in the file.
proc beginImmediate*(connection: Connection) =
  connection.executeScript("BEGIN IMMEDIATE;")
proc commit*(connection: Connection) = connection.executeScript("COMMIT;")
proc rollback*(connection: Connection) = connection.executeScript("ROLLBACK;")
proc schemaVersion*(connection: Connection): int = connection.scalarInt64(
    "PRAGMA user_version;").int
proc setSchemaVersion*(connection: Connection; version: int) =
  if version < 0: raise newException(ValueError, "schema version cannot be negative")
  # Formatted, not bound: PRAGMA takes no placeholders, and SQLite parses its
  # argument at prepare time. `version` is an int this procedure has already
  # refused when negative, so nothing a caller writes reaches the statement.
  connection.executeScript("PRAGMA user_version=" & $version & ";")

# --- Parameterised queries ---------------------------------------------------
# Everything below binds its arguments as text, which is what SQLite's dynamic
# typing expects and what a caller writing `?` placeholders means. A column
# declared INTEGER still stores an integer: SQLite applies the column's type
# affinity to a text value on the way in.
#
# The alternative -- interpolating values into the SQL -- is how injection
# happens, so there is deliberately no procedure here that takes a formatted
# statement.

proc bindAll(statement: Statement; args: openArray[string]) =
  for index, value in args:
    statement.bindText(index + 1, value)

proc columnCount*(statement: Statement): int =
  ## How many columns the statement's result has.
  statement.requireLive("counting SQLite columns")
  int(sqlite3_column_count(statement.handle))

proc columnName*(statement: Statement; index: int): string =
  ## The name SQLite gives a result column.
  statement.requireLive("reading a SQLite column name")
  let name = sqlite3_column_name(statement.handle, index.cint)
  if name == nil: "" else: $name

proc execute*(connection: Connection; sql: string;
    args: varargs[string, `$`]) =
  ## One statement, with `?` placeholders bound to `args`. Exactly one: a
  ## prepared statement is one statement by definition, and a script goes to
  ## `executeScript` instead.
  var statement = connection.prepare(sql)
  defer: statement.finalize
  statement.bindAll(args)
  discard statement.step

proc affectedRows*(connection: Connection): int =
  ## Rows the last INSERT, UPDATE or DELETE on this connection changed.
  if not connection.isOpen: connection.fail("counting affected rows")
  int(sqlite3_changes(connection.handle))

proc lastInsertId*(connection: Connection): int64 =
  ## The ROWID the last INSERT on this connection produced.
  if not connection.isOpen: connection.fail("reading the last insert id")
  sqlite3_last_insert_rowid(connection.handle)

proc row*(connection: Connection; sql: string;
    args: varargs[string, `$`]): seq[string] =
  ## The first row, every column as text, or an empty seq when there is none.
  ## Absence is an empty seq rather than an exception: "no such row" is an
  ## answer a caller acts on, not a failure.
  var statement = connection.prepare(sql)
  defer: statement.finalize
  statement.bindAll(args)
  if statement.step != rowAvailable: return @[]
  for index in 0 ..< statement.columnCount:
    result.add statement.columnText(index)

proc value*(connection: Connection; sql: string;
    args: varargs[string, `$`]): string =
  ## The first column of the first row, or "" when there is no row. A stored
  ## empty string and a missing row look the same here; use `row` when the
  ## difference matters.
  let first = connection.row(sql, args)
  if first.len == 0: "" else: first[0]

iterator rows*(connection: Connection; sql: string;
    args: varargs[string, `$`]): seq[string] =
  ## Every row, one at a time. The statement is finalized when the loop ends,
  ## including on a break -- `defer` in an iterator runs on every exit path.
  var statement = connection.prepare(sql)
  defer: statement.finalize
  statement.bindAll(args)
  let columns = statement.columnCount
  while statement.step == rowAvailable:
    var current = newSeqOfCap[string](columns)
    for index in 0 ..< columns:
      current.add statement.columnText(index)
    yield current
