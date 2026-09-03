# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "SQLite"

nbText: """
# SQLite

`openSqlite` gives a `Connection`. It creates the parent directory when asked,
reports SQLite's own diagnostics as `DatabaseError`, and closes a handle it
could not finish opening rather than handing back a half-built one.
"""

nbCode:
  import std/[os, tempfiles]
  import UniDatabase

  let directory = createTempDir("unidatabase-book-sqlite-", "")
  var connection = openSqlite(directory / "notes.sqlite")
  echo "open: ", connection.isOpen
  echo "capabilities: ", connection.capabilities

nbText: """
## Two ways to run SQL, and the difference is not convenience

`executeScript` runs every statement in the text, in order — a schema, a
migration. It takes no parameters, and nothing a caller supplies belongs in it.

`execute` runs exactly one statement and binds `?` placeholders to its
arguments. A bound value never becomes part of the statement text, and that is
the whole point.
"""

nbCode:
  connection.executeScript("""
    CREATE TABLE note(id INTEGER PRIMARY KEY, text TEXT, n INTEGER);
    CREATE INDEX note_n ON note(n);
  """)

  # A value that would end the statement and start another, if it were pasted
  # into the SQL instead of bound to it.
  const hostile = "'); DROP TABLE note; --"
  connection.execute("INSERT INTO note(text, n) VALUES (?, ?)", hostile, 1)

  echo "stored whole: ", connection.value(
    "SELECT text FROM note WHERE n = ?", 1) == hostile
  echo "table intact: ", connection.value("SELECT count(*) FROM note")

nbText: """
It came back exactly as it went in, and the table is still there. The string
was data for the whole of its life.

## Reading back

`value` for one cell, `row` for one row, `rows` to walk them. Every column
arrives as text — that is how SQLite stores it until someone asks otherwise.
"""

nbCode:
  connection.execute("INSERT INTO note(text, n) VALUES (?, ?)", "second", 2)

  echo "one cell: ", connection.value("SELECT text FROM note WHERE n = ?", 2)
  echo "one row:  ", connection.row("SELECT id, text, n FROM note WHERE n = ?", 2)
  for current in connection.rows("SELECT n, text FROM note ORDER BY n"):
    echo "  row: ", current

nbText: """
A missing row is an empty answer, not an exception — an empty sequence from
`row`, an empty string from `value`. "No such row" is something a caller acts
on, not a failure it has to catch.
"""

nbCode:
  echo "absent row:   ", connection.row("SELECT text FROM note WHERE n = ?", 99)
  echo "absent value: ", connection.value(
    "SELECT text FROM note WHERE n = ?", 99).len

nbText: """
## The two counters

SQLite keeps them per connection, for the statement that ran last.
"""

nbCode:
  echo "last insert id: ", connection.lastInsertId
  connection.execute("UPDATE note SET text = ? WHERE n > ?", "changed", 0)
  echo "rows affected:  ", connection.affectedRows

nbText: """
## Statements, when you need the handle

`prepare` gives a `Statement` to bind, step and read directly — which is what
`execute` and `rows` are built from. Bind with explicit byte lengths, so a value
holding a NUL byte survives; `columnText` reads SQLite's reported length rather
than trusting C-string termination, so it comes back whole.
"""

nbCode:
  const withNul = "a" & '\0' & "b"
  connection.execute("INSERT INTO note(text, n) VALUES (?, ?)", withNul, 3)
  let readBack = connection.value("SELECT text FROM note WHERE n = ?", 3)
  echo "bytes written: ", withNul.len, "  bytes read: ", readBack.len
  echo "identical:     ", readBack == withNul

  # SQLite's own `length()` stops at the first NUL, and says 1 for those three
  # bytes. That is the function's documented behaviour, not a truncated value:
  # the bytes are all there, as the comparison above shows.
  echo "SQL length():  ", connection.value(
    "SELECT length(text) FROM note WHERE n = ?", 3)

  connection.close
  removeDir(directory)

nbSave
