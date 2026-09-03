# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The failure paths. The happy path is covered next door; what is checked here
## is that every refusal is a DatabaseError carrying the engine's own words,
## and that a connection survives one.
import std/[os, strutils, tempfiles, unittest]
import UniDatabase

let scratchRoot = createTempDir("unidatabase-errors-", "")
  ## One directory the OS reserves for this run, holding every test's files.
  ##
  ## It used to be one fixed name per second under `getTempDir`, and only the
  ## flat database files were removed afterwards: the nested database and the
  ## root of the test that refuses to create a parent both outlived the run.
  ## One `mkdtemp` root, removed once, leaves nothing whatever a test does
  ## inside it -- and cannot collide with a run started in the same second.

proc scratch(name: string): string =
  ## A path inside this run's root. Each test gets its own subdirectory, so
  ## nothing a test leaves behind can be mistaken for another test's.
  result = scratchRoot / name.changeFileExt("") / name
  createDir(result.parentDir)



suite "SQLite refusals":
  test "a statement the engine rejects raises, and the connection survives":
    let path = scratch("refused.sqlite")
    var connection = openSqlite(path)
    expect DatabaseError:
      connection.execute("THIS IS NOT SQL")
    # Still usable: the failure was the statement's, not the connection's.
    connection.execute("CREATE TABLE t(x TEXT)")
    check connection.scalarInt64("SELECT COUNT(*) FROM t") == 0
    connection.close
    removeFile(path)

  test "preparing nonsense raises":
    let path = scratch("prepare.sqlite")
    var connection = openSqlite(path)
    expect DatabaseError:
      discard connection.prepare("SELECT FROM WHERE")
    connection.close
    removeFile(path)

  test "a closed connection refuses every operation":
    let path = scratch("closed.sqlite")
    var connection = openSqlite(path)
    connection.close
    check not connection.isOpen
    expect DatabaseError:
      connection.execute("CREATE TABLE t(x TEXT)")
    expect DatabaseError:
      discard connection.capabilities
    removeFile(path)

  test "closing twice is a no-op":
    let path = scratch("twice.sqlite")
    var connection = openSqlite(path)
    connection.close
    connection.close
    check not connection.isOpen
    removeFile(path)

  test "opening under a missing parent creates it, or refuses when told not to":
    let nested = scratch("deep") / "deeper" / "made.sqlite"
    var made = openSqlite(nested)
    check made.isOpen
    check fileExists(nested)
    made.close
    let absent = scratch("nomake") / "missing" / "refused.sqlite"
    expect DatabaseError:
      discard openSqlite(absent, createParent = false)

suite "SQLite values":
  test "bound integers come back as they went in":
    let path = scratch("ints.sqlite")
    var connection = openSqlite(path)
    connection.execute("CREATE TABLE n(v INTEGER)")
    var insertion = connection.prepare("INSERT INTO n(v) VALUES(?)")
    insertion.bindInt64(1, high(int64))
    check insertion.step == statementDone
    insertion.finalize
    check connection.scalarInt64("SELECT v FROM n") == high(int64)
    connection.close
    removeFile(path)

  test "a statement is reusable after reset, and rebindable after clearing":
    let path = scratch("reuse.sqlite")
    var connection = openSqlite(path)
    connection.execute("CREATE TABLE t(v TEXT)")
    var insertion = connection.prepare("INSERT INTO t(v) VALUES(?)")
    insertion.bindText(1, "first")
    check insertion.step == statementDone
    insertion.reset
    insertion.clearBindings
    insertion.bindText(1, "second")
    check insertion.step == statementDone
    insertion.finalize
    check connection.scalarInt64("SELECT COUNT(*) FROM t") == 2
    connection.close
    removeFile(path)

  test "an integer column read as text is still the same value":
    let path = scratch("cols.sqlite")
    var connection = openSqlite(path)
    connection.execute("CREATE TABLE t(v INTEGER)")
    connection.execute("INSERT INTO t(v) VALUES(42)")
    var query = connection.prepare("SELECT v FROM t")
    check query.step == rowAvailable
    check query.columnInt64(0) == 42
    check query.columnText(0) == "42"
    query.finalize
    connection.close
    removeFile(path)

  test "the declared capabilities are always present":
    let path = scratch("caps.sqlite")
    var connection = openSqlite(path)
    check preparedStatements in connection.capabilities
    check transactions in connection.capabilities
    check writeAheadLog in connection.capabilities
    connection.close
    removeFile(path)

  test "binding outside the statement's parameters raises":
    let path = scratch("bind.sqlite")
    var connection = openSqlite(path)
    connection.execute("CREATE TABLE t(v TEXT)")
    var insertion = connection.prepare("INSERT INTO t(v) VALUES(?)")
    # One parameter, so index 99 is not a parameter of this statement.
    expect DatabaseError:
      insertion.bindText(99, "nowhere")
    expect DatabaseError:
      insertion.bindInt64(99, 1)
    insertion.finalize
    connection.close
    removeFile(path)

suite "a finalized statement is refused, never answered":
  # `finalize` is idempotent, so a caller can reach any of these with a
  # finalized statement. Before the guards, four of the seven answered as if it
  # were live -- `columnInt64` gave 0 and `columnText` "" for a row holding 42
  # and "reel" -- and the behaviour was the linked SQLite's to decide. These
  # tests are what keeps the refusal from depending on that.
  proc finalized(connection: Connection): Statement =
    result = connection.prepare("SELECT 1")
    result.finalize

  test "finalize is idempotent, and says so":
    let path = scratch("finalize.sqlite")
    var connection = openSqlite(path)
    var statement = connection.prepare("SELECT 1")
    check statement.isLive
    statement.finalize
    check not statement.isLive
    statement.finalize # the second one is a no-op, not a double free
    check not statement.isLive
    connection.close
    removeFile(path)

  test "every operation on one raises DatabaseError":
    let path = scratch("dead.sqlite")
    var connection = openSqlite(path)

    var dead = connection.finalized
    expect DatabaseError: dead.bindText(1, "x")
    expect DatabaseError: dead.bindInt64(1, 1)
    expect DatabaseError: discard dead.step
    expect DatabaseError: dead.reset
    expect DatabaseError: dead.clearBindings
    expect DatabaseError: discard dead.columnText(0)
    expect DatabaseError: discard dead.columnInt64(0)

    connection.close
    removeFile(path)

  test "the message names the operation and the reason":
    let path = scratch("message.sqlite")
    var connection = openSqlite(path)
    var dead = connection.finalized
    try:
      discard dead.step
      check false # unreachable: the line above must raise
    except DatabaseError as error:
      check "stepping SQLite statement" in error.msg
      check "already finalized" in error.msg
    connection.close
    removeFile(path)

  test "a live statement is unaffected":
    let path = scratch("live.sqlite")
    var connection = openSqlite(path)
    connection.execute("CREATE TABLE note(id INTEGER, text TEXT)")
    var insert = connection.prepare("INSERT INTO note VALUES (?, ?)")
    insert.bindInt64(1, 7)
    insert.bindText(2, "kept")
    check insert.step == statementDone
    insert.reset
    insert.clearBindings
    insert.finalize

    var read = connection.prepare("SELECT id, text FROM note")
    check read.step == rowAvailable
    check read.columnInt64(0) == 7
    check read.columnText(1) == "kept"
    read.finalize

    connection.close
    removeFile(path)

# Last line of the module, not an exit hook: `unittest` runs each suite where it
# is written, so by here every test has finished, and the removal is ordered by
# the program rather than by whatever the runtime tears down first. An exit proc
# was tried and left the root behind.
removeDir(scratchRoot)
