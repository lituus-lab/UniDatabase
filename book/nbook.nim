# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The table of contents, and the two settings that decide the theme.
##
## Six chapters: what the library is, the boundary it draws, the SQLite API,
## transactions, and the two surfaces that reach it from outside Nim.
import std/tables
import nimibook
# `from ... import` and not a plain import: the theme module re-exports nimib
# for the chapters, and nimib's NbConfig has a `favicon_escaped` field too, so
# a plain import makes `book.favicon_escaped` below ambiguous.
from lituus_theme import faviconTag

var book = initBookWithToc:
  entry("UniDatabase", "index.nim")
  entry("Architecture", "architecture.nim")
  entry("SQLite", "sqlite.nim")
  entry("Transactions", "transactions.nim")
  entry("The C surface", "c_binding.nim")
  entry("The Python surface", "python_binding.nim")

book.title = "UniDatabase"
book.description = "A bounded SQLite backend: connections, statements, transactions."

# The two BookConfig fields that select a theme. nimibook's inline script picks
# between them with `prefers-color-scheme`, and localStorage overrides.
book.default_theme = "lituus-light"
book.preferred_dark_theme = "lituus-dark"
book.theme_option = {"lituus-light": "Light", "lituus-dark": "Dark"}.toTable

# From the theme package, not from a path beside this checkout: CI checks out
# one repository. Without it nimibook ships nimib's default, a whale emoji.
book.favicon_escaped = faviconTag()

nimibookCli(book)
