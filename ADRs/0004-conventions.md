<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: UniDatabase conventions

- Status: Accepted
- Date: 2026-07-15
- Scope: UniDatabase

## Layout

```text
UniDatabase.nimble          package + tasks
config.nims                 arch-conditional build flags
src/UniDatabase.nim         umbrella
src/UniDatabase/vendor/     SQLite's amalgamation, verbatim (see its README)
src/UniDatabase/sqlite_raw.nim  the C declarations, and nothing else
src/UniDatabase/sqlite.nim  the typed API callers use
src/UniDatabase/c_api.nim   C ABI
include/UniDatabase.h       hand-written C header
tests/ tests/c/             Nim + C ABI tests
examples/                   Nim + C demos
py/                         Cython binding + pytest
book/                       nimib book, code blocks run at build
ADRs/                       0001-0005
.github/workflows/ci.yml    3-OS Nim + C ABI + Python
LICENSE NOTICE CONTRIBUTING.md SECURITY.md .gitignore README.md AGENTS.md CLAUDE.md
```

## Naming

- Nim package/module: `UniDatabase` (PascalCase).
- C library: `libUniDatabase`. C header: `UniDatabase.h`.
- C symbol prefix: the library's own name in lower case, `unidatabase_`. Not a
  short token: a binary that links several engines at once holds them all in
  one namespace, and `ud_` has more than one plausible owner.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- No NimContracts here, and the dependency is not declared. Every check in this
  library guards a live SQLite handle or a C ABI, and both must hold under
  `-d:release`, where contracts are compiled away — a `require:` there would
  read as a guarantee the release build does not make. The family convention is
  to decide, not to carry the boilerplate unused.
- The C ABI never raises: `{.raises: [].}` on every entry point, a failure is a
  false or NULL return, and the reason waits in `unidatabase_last_error` until
  the next failing call overwrites it.
- A connection handle crossing the ABI is pinned with `GC_ref`: under `--mm:arc`
  the C caller holds the only reference, and nothing else keeps it alive.
- Layers, checked by `nimble checkVGraph`: `sqlite_raw` → `sqlite` → `c_api`,
  never upward. A layer named in `vgraph.cfg` that no file answers to
  constrains nothing, so the list is the real modules.

## CI gates

Every task runs through `tools/gate.nim`: nimble exits 0 on a task whose `exec`
failed, so its exit code proves nothing and the task's own success marker is
what the gate reads.

- `testCi` + `testCiRelease` on ubuntu/macOS/Windows.
- `ctest`, `cexample` and `clib` on ubuntu/macOS/Windows.
- the Python matrix on ubuntu/macOS/Windows, 3.10 to 3.14.
- `lint`, `checkVGraph`, `docs` and `coverage` on ubuntu.
- `canary`, which must fail.
- `all-green` over all of them: the one check branch protection requires.

A change to `c_api.nim` is verified by `ctest`, `pyTest` and, where there is
one, `wasmTest`: three linkages, three runtime bootstraps.
