<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# unidatabase — Python binding

Distributed as `lituus-unidatabase`, imported as `unidatabase`: the two names
are separate decisions, and the bare names are not all available on PyPI.

```bash
pip install lituus-unidatabase
```

From a checkout, `build/unigate pyTest` builds the extension and runs the tests
in one step. The pieces, if you want them apart:

```bash
build/unigate pyLib          # the C library the extension links against
build/unigate buildCython    # the extension, in place
build/unigate pyWheel        # a wheel in py/dist/
```

```python
from unidatabase import Database, version

version()                    # the C library's version

with Database("app.sqlite") as db:
    db.execute("CREATE TABLE note(text TEXT)")
    db.execute("INSERT INTO note VALUES ('kept')")
```

`Database` is a context manager; `close()` is idempotent, and using a closed
one raises `RuntimeError`. Every failure raises: the C ABI reports it as a
false return and leaves the reason in its own error slot, which the binding
reads before the next call can overwrite it.
