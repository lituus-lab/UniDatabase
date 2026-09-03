# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniDatabase"

nbText: """
# UniDatabase

A bounded SQLite backend for the lituus-lab Uni* family: one connection type,
prepared statements, explicit transactions, and a schema version the caller
owns. It wraps the system SQLite rather than vendoring one, so what it can do
is what the library on the machine can do — `capabilities` says which.

Three surfaces reach it, and they are the same engine underneath:

- **Nim** — `import UniDatabase`, the connection and statement types below.
- **C** — `include/UniDatabase.h`, an opaque handle and a single error slot.
- **Python** — `pip install lituus-unidatabase`, a `Database` context manager.

## What it refuses

Every failure is refused rather than absorbed. A statement the engine rejects
raises `DatabaseError` in Nim, returns 0 across the C ABI with the reason in
`unidatabase_last_error`, and raises `RuntimeError` in Python. A connection
survives a refused statement: the failure belongs to the statement.

The chapters that follow take each of those in turn.
"""

nbSave
