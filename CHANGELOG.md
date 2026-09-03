<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Changelog

Notable changes, newest first. Format after
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The C ABI has its own compatibility: a symbol removed or retyped is a major
change, whatever the Nim API did.

## [Unreleased]

Nothing released yet; 0.1.0 will be the first tag. What it will carry:

### Added

- The SQLite engine: connections, prepared statements, binding and column
  reads, transactions, the schema version, and a capability set answered for
  the connection at hand rather than for the library.
- `sqlite_raw`, the C declarations kept apart from the typed API, so a second
  backend can be a sibling of `sqlite` rather than a fork of it.
- A C ABI over the same engine, handle-based: a connection is an opaque
  pointer, pinned with `GC_ref` because under `--mm:arc` the C caller holds
  the only reference. Failures are a false or NULL return with the reason in
  `unidatabase_last_error`; no Nim exception crosses the boundary.
- A Cython binding, `unidatabase.Database`, usable as a context manager, which
  turns each of those failures back into an exception.
- `Statement.isLive`, and a guard on every other `Statement` procedure: a
  finalized statement is refused with `DatabaseError` rather than answered.
  Left to the linked SQLite, four of the seven answered as if it were live --
  `columnInt64` gave 0 for a row holding 42 -- so the refusal is the library's
  and does not depend on which SQLite was linked.
- The family's gates: `tools/gate.nim` and a success marker per task, a
  `canary` that must fail, `all-green` over every CI job, and
  `tests/test_version.nim` for the version's copies.

### Known limits

- SQLite only. What a second backend has to preserve before it is added is in
  ADR-0005.
- The `0.x` C ABI is not frozen.
