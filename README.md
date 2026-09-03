<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniDatabase

A database engine behind a backend-neutral typed API, for the `lituus-lab`
`Uni*` family. UniDatabase owns what a caller should not have to: connection
and prepared-statement lifecycles, binding and row access, transactions, the
schema version, and what the engine underneath actually supports. Schemas,
migrations, records and queries stay yours.

SQLite is the first backend, and the only one today. What a second has to
preserve before it is added is in `ADRs/0005-backend-boundary.md`; the API says
SQLite where it means SQLite (`openSqlite`) rather than claiming a portability
nothing has tested.

SQLite itself is **compiled in**, not linked from the system: the amalgamation
lives in `src/UniDatabase/vendor/`, so a build needs nothing installed and a
wheel needs no compiler.

Three surfaces, one engine: **Nim**, a **C ABI** (opaque handles, no exception
crosses), and a **Python** binding.

**Status: incubating.** The `0.x` C ABI is not frozen.

## Layout

```text
src/UniDatabase.nim             umbrella module
src/UniDatabase/vendor/         SQLite 3.50.4, verbatim (see its README)
src/UniDatabase/sqlite_raw.nim  the C declarations, and nothing else
src/UniDatabase/sqlite.nim      the typed API callers use
src/UniDatabase/c_api.nim       C ABI
include/UniDatabase.h           hand-written C header
tests/test_sqlite.nim           the happy path
tests/test_sqlite_errors.nim    every refusal, including SQLite's own
tests/c/                        C ABI test (links the header against the lib)
examples/                       Nim + C demos
py/                             Cython binding + pytest
book/                           the six-chapter book
ADRs/                           0001 DAG, 0002 license, 0003 engine&shell,
                                0004 conventions, 0005 backend boundary
tools/gate.nim                  the failure gate (see "Running a task")
tools/lint.nim tools/vgraph.nim nimpretty check, layer check
tests/canary_broken.nim         does not compile, on purpose
tests/test_version.nim          the version's copies must agree
.github/workflows/ci.yml        3-OS Nim matrix + C ABI + Python + all-green
CHANGELOG.md CITATION.cff CODE_OF_CONDUCT.md .editorconfig
```

## Build

```bash
nimble install -y
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate test           # Nim, debug
build/unigate testRelease    # Nim, release
build/unigate testAll        # debug + release + C ABI
build/unigate ctest          # C ABI: static lib + tests/c
build/unigate cexample       # C demo
build/unigate example        # Nim demo
build/unigate pyTest         # Cython + pytest
build/unigate coverage       # gcov + lcov -> coverage/
build/unigate book           # nimib book -> book/__site/
build/unigate docs           # book + API reference -> pages/
build/unigate canary         # must fail: proves the gate still works
```

## Using it

```nim
import UniDatabase

proc main() =
  # In a proc, not at module level: `defer` is not allowed there, and the
  # releases are the whole point of the example.
  var connection = openSqlite("app.sqlite")
  defer: connection.close

  connection.execute("CREATE TABLE note(id INTEGER PRIMARY KEY, text TEXT)")

  connection.beginImmediate()
  var statement = connection.prepare("INSERT INTO note(text) VALUES (?)")
  defer: statement.finalize
  statement.bindText(1, "kept")
  discard statement.step
  connection.commit()

  echo connection.scalarInt64("SELECT count(*) FROM note")

main()
```

`Connection` and `Statement` own a native handle and cannot be copied — the
compiler refuses it, because a copy would hold a pointer to memory SQLite had
freed. `close` and `finalize` are idempotent, and every operation on a released
handle raises `DatabaseError` rather than answering.

The PyPI distribution is `lituus-unidatabase`; the import name stays
`unidatabase`. Distribution and import are separate decisions, and the bare
names are not all available.

## Running a task

Nimble 0.22 exits 0 even when an `exec` inside a task failed: the exception is
printed, the task stops, and the process still reports success. `nimble test`
coming back 0 therefore proves only that nimble ran. Every task here ends by
writing its own success marker, and `tools/gate.nim` is what turns a missing
marker into a non-zero exit.

Run tasks through `build/unigate`, never bare, wherever the answer matters.
`build/unigate canary` compiles a source that cannot compile and must come back
non-zero; a CI job checks exactly that, because a gate nobody tests is a gate
nobody can trust.

## CI

`test`, `cabi` and `python` on ubuntu/macOS/Windows. `consume-cabi` and
`consume-wheel` rebuild against the published artifacts on a machine without Nim,
so what ships is what was tested. `coverage` and `docs` run on ubuntu. `canary`
checks that the gate still rejects a broken build.

`all-green` gathers every job's result and is the single check branch protection
requires: a job that was skipped or cancelled cannot pass for one that ran.

`dco` blocks PRs missing a `Signed-off-by` trailer; `commitizen` blocks PRs whose
commits or title are not [Conventional Commits](https://www.conventionalcommits.org/)
(`CONTRIBUTING.md`).

The same gates run locally with pre-commit: `pip install pre-commit && pre-commit install`
(`CONTRIBUTING.md`).

`pages` deploys the built docs, and is opt-in through the `PUBLISH_PAGES`
repository variable. It is off by default: across the family today every one of
these deployments reports success while every site answers 404, and a job that
is red forever teaches everyone to ignore red.

## AI-assisted contributions

Assistance from AI/LLM tools is welcome on the same terms as any other
contribution.

- **Accountability.** The human contributor is the author and remains fully
  responsible for the change. The DCO sign-off (`Signed-off-by`) is the mechanism:
  by signing you certify the content is yours or properly licensed — this covers
  AI-assisted work, provided you can stand behind it.
- **No third-party contamination.** Ensure AI output introduces no code from a
  third party without a compatible license and attribution. If an LLM reproduced
  protected material, do not submit it.
- **Correctness is yours.** The gates (tests, `nimble lint`, conventional commits,
  pre-commit) catch a lot, but you own the result — review and verify what you
  commit.
- **Atomic commits.** Each commit is one logical change. A PR may stack
  several atomic commits (one per element, say) — one monolithic big-bang
  commit is not.
- **Disclosure.** State in the PR whether AI assistance was used (see the PR
  template). It is not a hard requirement — the DCO remains the gate.

## License

Apache-2.0 (`LICENSE`). DCO sign-off on every commit (`CONTRIBUTING.md`).
