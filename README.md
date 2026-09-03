# UniDatabase 1.0.0

UniDatabase provides capability-oriented database foundations for Nim. The first validated backend
is SQLite because UniContext, agent-nim, UniDAV, UniMedia, and planned UniGeom work all provide
concrete SQLite demand.

The library owns connection and prepared-statement lifecycles, binding, row access, transactions,
and backend capabilities. Consumers continue to own schemas, migrations, records, and queries.
PostgreSQL and DuckDB will be added only from concrete requirements and will retain their native
capabilities.

```sh
nimble test
```

The project is private and is not published or installed globally. The public contract is covered
by the SQLite tests and the `book/` documentation entry point.

## Uni-Family relationship

UniDatabase is the persistence layer. It is deliberately independent from UniContext and can
support UniGeom, UniDAV, UniMedia, and other applications without imposing a schema.
