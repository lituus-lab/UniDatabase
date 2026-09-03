## SPDX-License-Identifier: Apache-2.0
import std/[os, times, unittest]
import UniDatabase

suite "SQLite capability backend":
  test "owns statements, transactions, and schema versions":
    let base = getTempDir() / ("unidatabase-" & $getTime().toUnix)
    createDir(base)
    let path = base / "fixture.sqlite"
    var connection = openSqlite(path)
    check connection.isOpen
    check preparedStatements in connection.capabilities
    connection.execute("CREATE TABLE items(id INTEGER PRIMARY KEY, value TEXT NOT NULL);")
    connection.beginImmediate
    var insertion = connection.prepare("INSERT INTO items(value) VALUES(?)")
    insertion.bindText(1, "portable")
    check insertion.step == statementDone
    insertion.finalize
    connection.commit
    check connection.scalarInt64("SELECT COUNT(*) FROM items") == 1
    connection.execute("INSERT INTO items(value) VALUES('a' || char(0) || 'b')")
    var nulQuery = connection.prepare("SELECT value FROM items WHERE id = 2")
    check nulQuery.step == rowAvailable
    check nulQuery.columnText(0).len == 3
    check nulQuery.columnText(0)[1] == '\0'
    nulQuery.finalize
    connection.setSchemaVersion(3)
    check connection.schemaVersion == 3

    connection.beginImmediate
    connection.execute("INSERT INTO items(value) VALUES('rolled back')")
    connection.rollback
    check connection.scalarInt64("SELECT COUNT(*) FROM items") == 2

    var query = connection.prepare("SELECT value FROM items WHERE id = 1")
    check query.step == rowAvailable
    check query.columnText(0) == "portable"
    check query.step == statementDone
    query.finalize
    connection.close
    check not connection.isOpen
    removeFile(path)
    removeDir(base)
