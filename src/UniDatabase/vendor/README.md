<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Vendored SQLite

`sqlite3.c` and `sqlite3.h` are the SQLite amalgamation, verbatim, compiled
into this library rather than linked from the system.

| | |
|---|---|
| Version | 3.50.4 |
| Source | <https://www.sqlite.org/2025/sqlite-amalgamation-3500400.zip> |
| `sqlite3.c` | `e3f5d6901e7492af4a1fc8c4d745cae84c264942524c3fbfc02b82a5ca8818c8` |
| `sqlite3.h` | `abd1514e0351f79393d1be882830afdb40a8099e8257f311f0bfdf8486f11bea` |
| Licence | public domain (the author disclaims copyright) |

## Why it is here

Every other engine in the family is self-contained: a wheel installs without a
compiler, and a source build needs nothing but Nim. Linking the system SQLite
broke that in two places at once — Windows runners carry no `sqlite3.h`, so
three CI jobs and the whole Python matrix could not build, and anyone
installing the sdist needed SQLite development files first.

It also pins what is being tested. `capabilities` asks the linked library what
it supports; with the system copy that answer changed per machine, and so did
the coverage of the branches that read it.

## Updating it

Download the amalgamation, replace both files, update the version and both
checksums above, and run the gates. Nothing else references SQLite's version,
so the table here is the record.

These two files carry no SPDX header and are not formatted by this repo's
tools: they are upstream's, unmodified, and a local edit would be lost at the
next update. `tools/hooks/spdx_check.sh` and `nimble coverage` skip this
directory for that reason.
