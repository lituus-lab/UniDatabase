# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "SQLite"

nbText: """
# SQLite backend

`openSqlite` creates parent directories when requested, reports SQLite diagnostics as
`DatabaseError`, and closes failed handles. Prepared statements bind text with explicit byte
lengths, so embedded NUL bytes remain valid. `columnText` uses SQLite's reported byte length and
does not rely on C-string termination.
"""

nbSave
