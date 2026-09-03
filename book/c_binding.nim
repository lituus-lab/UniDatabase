# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "The C surface"

nbText: """
# C ABI

The C header exposes version information and opaque SQLite connection operations. The consumer test
opens a database, executes SQL, and closes the handle without importing Nim.
"""

nbSave
