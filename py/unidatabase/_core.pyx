# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
cdef extern from "UniDatabase.h":
    const char *unidatabase_version()
    long long unidatabase_fibonacci(int n)
    # The domain bound comes from the header rather than being restated here:
    # one copy fewer to drift, and the Python check enforces exactly what the
    # C ABI clamps to.
    int UNIDATABASE_FIB_MAX_N


FIB_MAX_N = UNIDATABASE_FIB_MAX_N


def fibonacci(int n):
    """Raw C call (no domain check). Use unidatabase.fibonacci."""
    return unidatabase_fibonacci(n)


def version():
    return unidatabase_version()
