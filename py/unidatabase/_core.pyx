# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from libc.stdint cimport uintptr_t

cdef extern from "UniDatabase.h":
    const char *unidatabase_version()
    int unidatabase_abi_version()
    const char *unidatabase_last_error()
    void *unidatabase_open(const char *path)
    void unidatabase_close(void *connection)
    int unidatabase_execute(void *connection, const char *sql)


def version():
    return unidatabase_version()


def abi_version():
    return unidatabase_abi_version()


def last_error():
    """The message for the failure the last call reported. Borrowed: the C side
    owns it, and the next failing call overwrites it."""
    cdef const char *message = unidatabase_last_error()
    return b"" if message is NULL else <bytes>message


cdef class Connection:
    """Owns one C connection handle and closes it exactly once -- on close(),
    on leaving a `with`, or when the object is collected."""
    cdef void *_handle

    def __cinit__(self):
        self._handle = NULL

    def open(self, bytes path):
        # Refused rather than overwritten: this class is importable on its own,
        # and a second open would strand the first handle -- close() releases
        # only what _handle points at, so the first connection would stay open
        # for the life of the process.
        if self._handle is not NULL:
            raise RuntimeError("this connection is already open")
        self._handle = unidatabase_open(path)
        return self._handle is not NULL

    def execute(self, bytes sql):
        if self._handle is NULL:
            return False
        return unidatabase_execute(self._handle, sql) != 0

    def close(self):
        if self._handle is not NULL:
            unidatabase_close(self._handle)
            self._handle = NULL

    @property
    def is_open(self):
        return self._handle is not NULL

    def __dealloc__(self):
        self.close()
