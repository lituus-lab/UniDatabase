# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Architecture"

nbText: """
# Architecture

UniDatabase is a small ownership layer over SQLite. Two handles, and one rule
each.

| UniDatabase owns | Your application owns |
|---|---|
| the database handle, behind `Connection` | the schema and its migrations |
| the prepared statement, behind `Statement` | the domain records |
| when either becomes unusable, and how it says so | what the SQL means |

Underneath, `sqlite_raw` holds the C declarations and nothing else. `sqlite`
is the only module callers use, which is what lets a second backend be a
sibling of it rather than a fork — `vgraph.cfg` keeps that direction, and
`nimble checkVGraph` fails on an import that climbs.

## Closed means refused

Both handles are released explicitly and both releases are idempotent: calling
`close` or `finalize` twice is a no-op, not a double free. That is deliberate,
and it is why the rule below matters — a caller *can* legitimately hold a
handle that has already been released.

Every operation on a released handle raises `DatabaseError`. Not a wrong
answer, not undefined behaviour: a refusal that names what was attempted.
"""

nbCode:
  import std/os
  import UniDatabase

  let directory = getTempDir() / "unidatabase-book-architecture"
  createDir(directory)
  var connection = openSqlite(directory / "ownership.sqlite")
  connection.execute("CREATE TABLE note(n INTEGER, s TEXT)")
  connection.execute("INSERT INTO note VALUES (42, 'reel')")

  var statement = connection.prepare("SELECT n, s FROM note")
  discard statement.step
  echo "live:      n=", statement.columnInt64(0), " s=", statement.columnText(1)

  statement.finalize
  statement.finalize # idempotent
  echo "isLive:    ", statement.isLive

  try:
    echo "finalized: n=", statement.columnInt64(0)
  except DatabaseError as error:
    echo "finalized: ", error.msg

nbText: """
That refusal is the library's, not SQLite's. Left to the linked SQLite, four of
the seven `Statement` operations answered as if the statement were live — that
same column read gave `0`, and the text column `""`, for the row holding 42 and
`"reel"`. A plausible wrong answer is worse for a caller than an error, and
which answers you got depended on which SQLite the binary linked.

The same holds for a closed connection:
"""

nbCode:
  connection.close
  connection.close # idempotent
  echo "isOpen:    ", connection.isOpen

  try:
    connection.execute("SELECT 1")
  except DatabaseError as error:
    echo "closed:    ", error.msg

  removeDir(directory)

nbText: """
## Capabilities are asked, not assumed

`capabilities` answers for the connection at hand rather than for the library.
FTS5 is compiled into some SQLite builds and not others, so it is queried —
declaring it unconditionally would be a claim about a binary this library does
not choose.
"""

nbSave
