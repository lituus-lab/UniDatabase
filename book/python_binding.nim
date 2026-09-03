# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, osproc, strutils]
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "The Python surface"

const Root = currentSourcePath().parentDir.parentDir

proc run(command: string): string =
  let (output, code) = execCmdEx("cd " & Root.quoteShell & " && " & command)
  result = output.strip
  if code != 0:
    raise newException(OSError,
      "book: `" & command & "` exited " & $code & "\n" & result)

nbText: """
# The Python surface

`unidatabase.Database` is a Cython extension over the C ABI — not a `ctypes`
layer: the binding compiles against `UniDatabase.h`, so a header that drifts
fails to build rather than at a caller's site.

It owns the opaque connection and is a context manager. Leaving the block
closes it; `close()` is idempotent, and every failure the C ABI reports as a
false return becomes an exception here.
"""

nbCode:
  echo run("""PYTHONPATH=py python3 -c '
import tempfile, pathlib, unidatabase

print("version:", unidatabase.version(), "ABI:", unidatabase.abi_version())

with tempfile.TemporaryDirectory() as directory:
    path = str(pathlib.Path(directory) / "book.sqlite")
    with unidatabase.Database(path) as db:
        db.execute("CREATE TABLE note(id INTEGER PRIMARY KEY, text TEXT)")
        db.execute("INSERT INTO note(text) VALUES (\"kept\")")
        print("open inside the block:", db.is_open)
    print("closed on leaving it: ", not db.is_open)
'""")

nbText: """
## What it refuses

Three refusals, none of which a caller can reach by accident but each of which
would be silent without the check:
"""

nbCode:
  echo run("""PYTHONPATH=py python3 -c '
import tempfile, pathlib, unidatabase

with tempfile.TemporaryDirectory() as directory:
    path = str(pathlib.Path(directory) / "refusals.sqlite")
    db = unidatabase.Database(path)
    db.close()
    try:
        db.execute("SELECT 1")
    except RuntimeError as exc:
        print("closed database :", exc)

    with unidatabase.Database(path) as open_db:
        try:
            open_db.execute("SELECT * FROM absent_table")
        except RuntimeError as exc:
            print("SQLite refusal :", exc)

    try:
        unidatabase.Database(path + chr(0) + "ignored")
    except ValueError as exc:
        print("embedded NUL   :", exc)
'""")

nbText: """
The last one is the least obvious. The C ABI reads a NUL-terminated string, so
a path containing `\0` would reach SQLite truncated at that byte — the file
opened would not be the file named. Python strings can hold it, C strings
cannot, and the binding is where that mismatch has to be caught.

## The distribution

`pip install lituus-unidatabase`; the import name stays `unidatabase`. The
wheel bundles the shared library beside the extension and finds it through an
rpath relative to it, so an installed package needs nothing else on the system.
Building from the sdist compiles the vendored Nim source instead, and needs Nim
on `PATH`.
"""

nbSave
