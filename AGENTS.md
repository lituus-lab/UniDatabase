<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniDatabase

## Build & gates

```bash
nimble install -y
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate testAll    # Nim debug + release + C ABI
build/unigate pyTest     # Cython + pytest (needs libUniDatabase.so)
build/unigate example
build/unigate coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
build/unigate docs       # nimib book + API reference -> pages/ (needs nimib)
build/unigate canary     # must fail
```

Never `nimble <task>` bare where the answer matters: nimble 0.22 exits 0 even
when an `exec` inside the task failed. The gate reads the task's own success
marker instead, which is the only evidence it ran to its last line.

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: Nim, C ABI and Python each on ubuntu/macOS/Windows; lint, docs and
coverage on ubuntu; a canary job that must fail; `all-green` over all of them.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- No NimContracts here, and the dependency is not declared: every check in this
  library guards a live SQLite handle or a C ABI, and both must hold under
  `-d:release`, where contracts are compiled away.
- `defer` is not allowed at module level, `when isMainModule` included. Every
  example that releases a handle therefore lives in a proc; written flat it does
  not compile, which has caught `examples/demo.nim` and the README once each.
  Extract every fenced Nim block that imports and compile it before shipping.
- SQLite is compiled in from `src/UniDatabase/vendor/`, never linked from the
  system. Windows runners carry no `sqlite3.h`, and an sdist install needed
  development files no wheel user has. Nothing links `-lsqlite3`: the C
  Makefiles name only what SQLite itself calls into (libm, and dl/pthread on
  Linux). `spdx_check.sh` and `coverage` skip that directory -- upstream's
  files, unmodified.
- The C ABI never raises: `{.raises: [].}` on every entry point, a failure is a
  false or NULL return, and the reason waits in `unidatabase_last_error`.
- A handle crossing the ABI is pinned with `GC_ref`; under `--mm:arc` the C
  caller holds the only reference.
- A postcondition is cheaper than the body: never re-derives the result by
  calling the function itself.
- C ABI: hand-written `include/UniDatabase.h` kept in sync with
  `src/UniDatabase/c_api.nim`; `tests/c` links the header against the lib.
  Built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`.
- A change to `c_api.nim` is verified by `ctest`, `pyTest` and, where there
  is one, `wasmTest`: three linkages, three runtime bootstraps. A green
  `ctest` alone proved nothing the day the shared build lost its
  initializer and every registry answered with the sentinel.
- C symbols `unidatabase_*` — the library's own name in lower case, not a
  short token: a binary linking several engines holds them in one namespace.
  Lib `libUniDatabase`; header `UniDatabase.h`.
- `book/index.nim` is nimib: its code blocks are compiled and run at docs build,
  so prose that outlives its API breaks the build. `py/notebooks/quickstart.ipynb`
  plays the same role for Python and renders natively on GitHub.
- End covered sources with a blank line. Nim maps a trailing statement one line
  past EOF; without that line lcov aborts on `range`/`unmapped`, and `coverage`
  keeps those fatal so the failure stays visible. It ignores exactly one error,
  `mismatch`, which lcov 2.0 raises on a compiler-generated destructor and lcov
  2.5 does not — a generated symbol, not a line of the library.
- Coverage instruments `tests/test_all.nim` alone: gcov data for a second
  compilation into the same nimcache overwrites the first.
- `vgraph.cfg` must name the modules that exist. A layer no file answers to
  constrains nothing, and `checkVGraph` then passes on a graph it never read.

## Scope

A SQLite database engine: connections, prepared statements, transactions,
schema version and capability reporting, reachable from Nim, from C and from
Python. SQLite only for now — what a second backend has to preserve is in
ADR-0005. Apache-2.0, DCO.
