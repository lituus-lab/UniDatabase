<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0005: one backend first, and what a second one has to preserve

- Status: Accepted
- Date: 2026-09-03
- Scope: UniDatabase

## Context

A database library that abstracts over several engines from the start ends up
with the intersection of what they all do, and callers discover the differences
anyway — through error text, transaction semantics, or a capability that is
present on one backend and absent on another.

## Decision

SQLite only, for now, and reached through a typed API rather than the raw
declarations. A second backend is added when it can preserve, unchanged:

- **Ownership.** A connection is closed once; closing an already-closed one is
  a no-op, and a statement is finalized by its owner.
- **Errors.** Every failure raises `DatabaseError` carrying the engine's own
  message, never a code the caller has to look up.
- **Transactions.** `beginImmediate` / `commit` / `rollback` mean what they
  mean in SQLite: a write transaction is taken at the start, not on first
  write.
- **Capabilities.** `capabilities` answers for the connection at hand rather
  than for the library. FTS5 is reported only when the linked SQLite was built
  with it — which is why it is queried, not assumed.

## Consequences

- `sqlite_raw` holds the C declarations and nothing else; `sqlite` is the only
  module callers use. A second backend is a sibling of `sqlite`, not a fork of
  it, and `vgraph.cfg` is what keeps that direction.
- Until then, the API is honest about being SQLite's: `openSqlite`, `PRAGMA
  user_version` as the schema version. Renaming those to look neutral would
  claim a portability nothing has tested.
- A caller who needs PostgreSQL today should not use this library and find out
  later; it says SQLite in the name of its entry point.
