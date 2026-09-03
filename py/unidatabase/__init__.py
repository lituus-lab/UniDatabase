# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""unidatabase — Python binding over the UniDatabase C library."""
from ._core import Connection as _Connection, abi_version as _abi_c, \
    last_error as _last_error_c, version as _version_c

__version__ = _version_c().decode("ascii")


def version():
    """C library version string."""
    return _version_c().decode("ascii")


def abi_version():
    """C ABI generation. A consumer built against a different one is not
    compatible with this library."""
    return _abi_c()


class Database:
    """A SQLite connection. Use it as a context manager, or close() it.

    Every failure raises: the C ABI reports it as a false return and leaves the
    reason in its own error slot, which is read here before the next call can
    overwrite it.
    """

    def __init__(self, path):
        if not isinstance(path, str):
            raise TypeError(f"path must be str, got {type(path).__name__}")
        # The C ABI reads a NUL-terminated string: an embedded NUL would make
        # SQLite see only the prefix, and open a file the caller did not name.
        if "\x00" in path:
            raise ValueError("path must not contain a NUL character")
        self._connection = _Connection()
        if not self._connection.open(path.encode("utf-8")):
            raise RuntimeError(_error("cannot open " + path))

    def execute(self, sql):
        """Run one statement. Raises RuntimeError on a closed connection or a
        statement the engine refused."""
        if not isinstance(sql, str):
            raise TypeError(f"sql must be str, got {type(sql).__name__}")
        if "\x00" in sql:
            raise ValueError("sql must not contain a NUL character")
        if not self._connection.is_open:
            raise RuntimeError("the database is closed")
        if not self._connection.execute(sql.encode("utf-8")):
            raise RuntimeError(_error("cannot execute the statement"))

    def close(self):
        """Idempotent."""
        self._connection.close()

    @property
    def is_open(self):
        return self._connection.is_open

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
        return False


def _error(fallback):
    message = _last_error_c().decode("utf-8", "replace").strip()
    return message if message else fallback


__all__ = ["Database", "version", "abi_version", "__version__"]
