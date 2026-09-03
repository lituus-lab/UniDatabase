# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Transactions"

nbText: """
# Transactions and statements

Use `beginImmediate`, `commit`, and `rollback` for explicit transaction boundaries. Finalize a
statement after use, preferably with `defer`. `reset` and `clearBindings` support statement reuse.
The release tests cover commit, rollback, schema versions, capability detection, and embedded NUL
text.
"""

nbSave
