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

/* Conventions:
 *   * A connection is an opaque void*. This library owns it; release it with
 *     unidatabase_close. NULL is a no-op for close.
 *   * A call that fails returns NULL or 0 and leaves its reason in
 *     unidatabase_last_error. That slot holds one message: the next failing
 *     call overwrites it, so read it before calling again.
 *   * No Nim exception crosses this boundary; every entry point traps.
 *   * A connection carries no lock. One thread at a time may use or close a
 *     given one; a caller sharing one across threads serialises that itself.
 *   * The error slot is one for the whole library, not one per thread, and it
 *     is not synchronised. Two threads failing at once race on it, and a
 *     returned pointer can be invalidated by another thread's failure before
 *     it is read. Read it on the thread that made the failing call, before any
 *     other call on any thread. */

/* Static version string; do not free. */
const char *unidatabase_version(void);

/* C ABI generation. A consumer built against a different one is not
 * compatible with this library. */
int unidatabase_abi_version(void);

/* The reason the last call failed, or "" when none has. Borrowed: do not
 * free, and copy it if it must outlive the next call. */
const char *unidatabase_last_error(void);

/* Open the SQLite database at `path`. NULL on failure. */
void *unidatabase_open(const char *path);

/* Release a connection. NULL is a no-op. */
void unidatabase_close(void *connection);

/* Run SQL. Every statement in the text runs, in order -- a semicolon-separated
 * script is executed whole, which is what a schema or a migration is.
 * 1 on success, 0 on failure, with the reason in unidatabase_last_error.
 *
 * There are no placeholders here: a value must never be formatted into this
 * string. The Nim and Python APIs take bound parameters for that. */
int unidatabase_execute(void *connection, const char *sql);

#ifdef __cplusplus
}
#endif

#endif /* UNIDATABASE_H */
