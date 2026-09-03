## SPDX-License-Identifier: Apache-2.0
## The SQLite C library, compiled in rather than linked from the system: see
## vendor/README.md for the version, the checksums and why.

import std/os

{.compile: "vendor/sqlite3.c".}

# The include directory, computed from this file's own location: `header:`
# below emits a literal `#include "sqlite3.h"`, which the C compiler resolves
# against its include path and not against this module. Quoted, because an
# installed package can sit under a path with a space in it.
const vendorDir = currentSourcePath().parentDir / "vendor"
{.passC: "-I\"" & vendorDir & "\"".}

# FTS5 is off in the amalgamation's defaults, and `capabilities` reports it, so
# it is asked for here rather than left to whatever was linked. Everything else
# stays at upstream's defaults.
{.passC: "-DSQLITE_ENABLE_FTS5".}

when defined(linux):
  # SQLite calls into libm, dlopen and pthreads; the system copy pulled them in
  # through its own link line, and the amalgamation has to name them itself.
  {.passL: "-lm -ldl -lpthread".}
elif defined(macosx):
  {.passL: "-lm".}

type
  Sqlite3* {.importc: "sqlite3", header: "sqlite3.h",
      incompleteStruct.} = object
  SqliteStmt* {.importc: "sqlite3_stmt", header: "sqlite3.h",
      incompleteStruct.} = object

const
  SqliteOk* = 0.cint
  SqliteRow* = 100.cint
  SqliteDone* = 101.cint
  SqliteOpenReadWrite* = 0x00000002.cint
  SqliteOpenCreate* = 0x00000004.cint

proc sqlite3_open_v2*(filename: cstring; db: ptr ptr Sqlite3; flags: cint;
    vfs: cstring): cint {.cdecl, importc, header: "sqlite3.h".}
proc sqlite3_close*(db: ptr Sqlite3): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_errmsg*(db: ptr Sqlite3): cstring {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_exec*(db: ptr Sqlite3; sql: cstring; callback: pointer;
    argument: pointer; errorMessage: ptr cstring): cint {.cdecl, importc,
        header: "sqlite3.h".}
proc sqlite3_free*(memory: pointer) {.cdecl, importc, header: "sqlite3.h".}
proc sqlite3_prepare_v2*(db: ptr Sqlite3; sql: cstring; bytes: cint;
    statement: ptr ptr SqliteStmt; tail: pointer): cint {.cdecl, importc,
        header: "sqlite3.h".}
  ## `tail` is `const char **` in SQLite, and Nim's `ptr cstring` emits
  ## `char **`. C converts `char *` to `const char *` implicitly but not
  ## `char **` to `const char **`, so gcc 14 and later reject the call outright;
  ## clang and older gcc only warned, which is why this only ever failed on
  ## Windows. `pointer` is `void *`, which converts to either -- and this
  ## library always passes nil, having no use for the unparsed tail.
proc sqlite3_bind_text*(statement: ptr SqliteStmt; index: cint; value: cstring;
    bytes: cint; destructor: pointer): cint {.cdecl, importc,
        header: "sqlite3.h".}
proc sqlite3_bind_int64*(statement: ptr SqliteStmt; index: cint;
    value: int64): cint
    {.cdecl, importc, header: "sqlite3.h".}
proc sqlite3_step*(statement: ptr SqliteStmt): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_reset*(statement: ptr SqliteStmt): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_clear_bindings*(statement: ptr SqliteStmt): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_finalize*(statement: ptr SqliteStmt): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_column_text*(statement: ptr SqliteStmt; column: cint): cstring
    {.cdecl, importc, header: "sqlite3.h".}
proc sqlite3_column_bytes*(statement: ptr SqliteStmt; column: cint): cint
    {.cdecl, importc, header: "sqlite3.h".}
proc sqlite3_column_int64*(statement: ptr SqliteStmt; column: cint): int64
    {.cdecl, importc, header: "sqlite3.h".}
proc sqlite3_compileoption_used*(option: cstring): cint
    {.cdecl, importc, header: "sqlite3.h".}

let SqliteTransient* = cast[pointer](-1)

proc sqlite3_column_count*(statement: ptr SqliteStmt): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_column_name*(statement: ptr SqliteStmt; index: cint): cstring {.
    cdecl, importc, header: "sqlite3.h".}
proc sqlite3_last_insert_rowid*(db: ptr Sqlite3): int64 {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_changes*(db: ptr Sqlite3): cint {.cdecl, importc,
    header: "sqlite3.h".}
proc sqlite3_bind_null*(statement: ptr SqliteStmt; index: cint): cint {.cdecl,
    importc, header: "sqlite3.h".}
