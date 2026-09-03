# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## A whole session: open, create, insert inside a transaction, read back, and
## the schema version SQLite carries for you. Written into a temporary
## directory that is removed at the end, so running the demo twice is the same
## as running it once -- and so it works on Windows, which has no /tmp.
import std/[os, sequtils, strutils]
import UniDatabase

proc main() =
  let directory = getTempDir() / "unidatabase-demo"
  createDir(directory)
  defer: removeDir(directory)

  var connection = openSqlite(directory / "demo.sqlite")
  defer: connection.close

  echo "open:         ", connection.isOpen
  echo "capabilities: ", connection.capabilities.toSeq.join(", ")

  connection.execute("CREATE TABLE note(id INTEGER PRIMARY KEY, text TEXT)")

  # A write transaction taken at the start, not on first write: that is what
  # `IMMEDIATE` means, and it is why two writers fail fast rather than deadlock.
  connection.beginImmediate()
  var statement = connection.prepare("INSERT INTO note(text) VALUES (?)")
  for text in ["kept", "also kept"]:
    statement.bindText(1, text)
    discard statement.step
    statement.reset
    statement.clearBindings
  statement.finalize
  connection.commit()

  echo "rows:         ", connection.scalarInt64("SELECT count(*) FROM note")

  # Rolled back, so the row never existed as far as the next query is concerned.
  connection.beginImmediate()
  connection.execute("INSERT INTO note(text) VALUES ('discarded')")
  connection.rollback()
  echo "after rollback: ", connection.scalarInt64("SELECT count(*) FROM note")

  connection.setSchemaVersion(3)
  echo "schema:       ", connection.schemaVersion

when isMainModule:
  main()
