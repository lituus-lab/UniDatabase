# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Author py/notebooks/quickstart.ipynb, then execute it so the committed file
carries real outputs for GitHub to render. Run from the repo root:

    python3 py/notebooks/build_quickstart.py

CI re-executes the notebook against an installed wheel; this script only
regenerates it after an API change."""
import os

import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ("md", """# UniDatabase — Python quickstart

`unidatabase` is a Cython extension over the UniDatabase C ABI, shipped as a
self-contained wheel: the native library travels inside the package, so
installing it needs neither Nim nor a compiler.

```
pip install lituus-unidatabase
```

CI executes this notebook against the wheel the release actually publishes, so
an output below that stops matching fails the build."""),
    ("md", "## The API"),
    ("code", """import tempfile
from pathlib import Path

import unidatabase

unidatabase.version(), unidatabase.abi_version()"""),
    ("md", """## A database

`Database` opens a SQLite file and is a context manager: leaving the block
closes the connection. The parent directory is created if it is missing."""),
    ("code", """directory = tempfile.TemporaryDirectory()
path = str(Path(directory.name) / "quickstart.sqlite")

db = unidatabase.Database(path)
db.execute("CREATE TABLE note(id INTEGER PRIMARY KEY, text TEXT)")
db.execute("INSERT INTO note(text) VALUES ('kept')")
db.is_open"""),
    ("md", """## Closing

`close()` is idempotent — calling it twice is not an error, which matters
because the C ABI owns the handle and a double free would not be recoverable."""),
    ("code", """db.close()
db.close()
db.is_open"""),
    ("md", """Using a closed database raises rather than failing quietly:"""),
    ("code", """try:
    db.execute("SELECT 1")
except RuntimeError as exc:
    print("RuntimeError:", exc)"""),
    ("md", """## Errors carry SQLite's own message

The C ABI reports a failure as a false return and leaves the reason in its own
error slot; the binding reads it before the next call can overwrite it, and
raises with it."""),
    ("code", """with unidatabase.Database(path) as db:
    try:
        db.execute("SELECT * FROM a_table_that_does_not_exist")
    except RuntimeError as exc:
        print("RuntimeError:", exc)"""),
    ("md", "A path that is not a string is a type error, not a coercion."),
    ("code", """try:
    unidatabase.Database(42)
except TypeError as exc:
    print("TypeError:", exc)"""),
    ("code", "directory.cleanup()"),
    ("md", """## The C ABI underneath

The same engine is reachable from anything that speaks C, handle-based:

```c
void *unidatabase_open(const char *path);
int   unidatabase_execute(void *connection, const char *sql);
void  unidatabase_close(void *connection);
const char *unidatabase_last_error(void);
```

There a failure is a NULL or zero return with the reason in
`unidatabase_last_error`, because an exception must never unwind across an ABI
boundary.

See `include/UniDatabase.h`, and the book for the full picture."""),
]


def main():
    nb = nbf.v4.new_notebook()
    nb.cells = [
        nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src)
        for kind, src in CELLS
    ]
    nb.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    # Execute from the repo root, never from py/: there, `import unidatabase`
    # would resolve to the py/unidatabase source tree instead of the installed
    # package, and the notebook would stop testing what it claims to test.
    NotebookClient(nb, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": ROOT}}).execute()
    with open(OUT, "w") as f:
        nbf.write(nb, f)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
