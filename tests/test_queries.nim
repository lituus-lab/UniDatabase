# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The parameterised layer: `?` placeholders, rows read back as text, and the
## two counters SQLite keeps per connection. What is checked here is that a
## value never reaches SQLite as part of the statement text -- which is the
## whole reason this layer exists rather than string formatting.
import std/[os, tempfiles, unittest]
import UniDatabase

let queryRoot = createTempDir("unidatabase-queries-", "")

proc scratch(name: string): string =
  result = queryRoot / name / (name & ".sqlite")
  createDir(result.parentDir)

proc seeded(path: string): Connection =
  result = openSqlite(path)
  result.execute("CREATE TABLE note(id INTEGER PRIMARY KEY, text TEXT, n INTEGER)")
  result.execute("INSERT INTO note(text, n) VALUES (?, ?)", "first", 1)
  result.execute("INSERT INTO note(text, n) VALUES (?, ?)", "second", 2)

suite "parameterised statements":
  test "arguments are bound, never interpolated":
    var connection = seeded(scratch("bound"))
    # A value that would end the statement if it were pasted into the SQL. It
    # comes back whole, and the table is still there.
    let hostile = "'); DROP TABLE note; --"
    connection.execute("INSERT INTO note(text, n) VALUES (?, ?)", hostile, 3)
    check connection.value("SELECT text FROM note WHERE n = ?", 3) == hostile
    check connection.value("SELECT count(*) FROM note") == "3"
    connection.close

  test "a missing row is an empty answer, not an exception":
    var connection = seeded(scratch("missing"))
    check connection.row("SELECT text FROM note WHERE n = ?", 99).len == 0
    check connection.value("SELECT text FROM note WHERE n = ?", 99) == ""
    connection.close

  test "every column of the first row comes back as text":
    var connection = seeded(scratch("row"))
    let first = connection.row("SELECT id, text, n FROM note ORDER BY id")
    check first == @["1", "first", "1"]
    connection.close

  test "rows walks them all, and finalizes on a break":
    var connection = seeded(scratch("rows"))
    var seen: seq[string] = @[]
    for current in connection.rows("SELECT text FROM note ORDER BY id"):
      seen.add current[0]
    check seen == @["first", "second"]

    # Leaving early must still release the statement, or the connection cannot
    # be closed -- SQLite refuses that with SQLITE_BUSY.
    for current in connection.rows("SELECT text FROM note ORDER BY id"):
      break
    connection.close
    check not connection.isOpen

  test "the counters answer for the last statement":
    var connection = seeded(scratch("counters"))
    check connection.lastInsertId == 2
    connection.execute("UPDATE note SET text = ? WHERE n > ?", "changed", 0)
    check connection.affectedRows == 2
    connection.execute("DELETE FROM note WHERE n = ?", 1)
    check connection.affectedRows == 1
    connection.close

  test "column names come from the statement":
    var connection = seeded(scratch("names"))
    var statement = connection.prepare("SELECT id, text FROM note")
    check statement.columnCount == 2
    check statement.columnName(0) == "id"
    check statement.columnName(1) == "text"
    statement.finalize
    connection.close

  test "a closed connection refuses the counters":
    var connection = seeded(scratch("closed"))
    connection.close
    expect DatabaseError: discard connection.affectedRows
    expect DatabaseError: discard connection.lastInsertId

removeDir(queryRoot)
