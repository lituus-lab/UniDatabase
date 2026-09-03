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

const SqliteCapabilities* = {preparedStatements, transactions, writeAheadLog}

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
  if sqlite3_compileoption_used("ENABLE_FTS5") != 0:
    result.incl(fullTextSearch5)

proc close*(connection: var Connection) =
  if connection.handle != nil:
    if sqlite3_close(connection.handle) != SqliteOk:
      connection.fail("closing SQLite")
    connection.handle = nil

proc execute*(connection: Connection; sql: string) =
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
    if sqlite3_finalize(statement.handle) != SqliteOk:
      raise newException(DatabaseError, "finalizing SQLite statement")
    statement.handle = nil

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

proc beginImmediate*(connection: Connection) = connection.execute("BEGIN IMMEDIATE;")
proc commit*(connection: Connection) = connection.execute("COMMIT;")
proc rollback*(connection: Connection) = connection.execute("ROLLBACK;")
proc schemaVersion*(connection: Connection): int = connection.scalarInt64(
    "PRAGMA user_version;").int
proc setSchemaVersion*(connection: Connection; version: int) =
  if version < 0: raise newException(ValueError, "schema version cannot be negative")
  connection.execute("PRAGMA user_version=" & $version & ";")
