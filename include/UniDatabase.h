// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#ifndef UNIDATABASE_H
#define UNIDATABASE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNIDATABASE_VERSION_MAJOR 0
#define UNIDATABASE_VERSION_MINOR 1
#define UNIDATABASE_VERSION_PATCH 0
#define UNIDATABASE_VERSION "0.1.0"

#define UNIDATABASE_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNIDATABASE_VERSION_MAJOR > (ma)) || \
   (UNIDATABASE_VERSION_MAJOR == (ma) && UNIDATABASE_VERSION_MINOR > (mi)) || \
   (UNIDATABASE_VERSION_MAJOR == (ma) && UNIDATABASE_VERSION_MINOR == (mi) && \
    UNIDATABASE_VERSION_PATCH >= (pa)))

/* Largest n with unidatabase_fibonacci(n) fitting in long long (int64). */
#define UNIDATABASE_FIB_MAX_N 92

/* Static version string; do not free. */
const char *unidatabase_version(void);

/* fibonacci(n), n clamped to [0, UNIDATABASE_FIB_MAX_N].
 * n < 0 -> 0; n > UNIDATABASE_FIB_MAX_N -> fibonacci(UNIDATABASE_FIB_MAX_N).
 * Never raises. Single-threaded, reentrant. */
long long unidatabase_fibonacci(int n);

#ifdef __cplusplus
}
#endif

#endif /* UNIDATABASE_H */
