# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "The Python surface"

nbText: """
# Python binding

The Python package is a thin `ctypes` layer over the C ABI. `Database` owns the opaque connection and
offers explicit execution and context-manager cleanup.
"""

nbSave
