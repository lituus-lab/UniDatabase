# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniDatabase. Built --app:staticlib/--app:lib --noMain --mm:arc
## -d:release. Keep in sync with include/UniDatabase.h; tests/c links the header
## against this lib, so a header that drifts fails to compile rather than at a
## caller's site.
##
## No Nim exception crosses this boundary: `{.raises: [].}` on every entry
## point is what proves it rather than a convention that has to be remembered.
import ../UniDatabase

const UniDatabaseVersionC: cstring = "0.1.0"

# Unmangled C symbols, C calling convention, exported from the shared lib.
# --noMain suppresses the generated entry point and with it every auto-init
# hook: neither the static nor the shared build emits a DllMain or an ELF
# constructor, so nothing initializes the Nim runtime. The first entry point
# then enters Nim code whose globals were never set up. The shared build was
# assumed to be covered by a loader hook it does not have -- its registries
# stayed empty and the contrast entry answered nan. Every --noMain task passes
# -d:noAutoInit; an ordinary executable linking this module must not, since its
# own main already ran NimMain.
when defined(noAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE unidatabase_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK unidatabase_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void unidatabase_runtime_ensure(void) {
  InitOnceExecuteOnce(&unidatabase_runtime_once, unidatabase_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t unidatabase_runtime_once = PTHREAD_ONCE_INIT;
static void unidatabase_runtime_init(void) { NimMain(); }
static void unidatabase_runtime_ensure(void) {
  pthread_once(&unidatabase_runtime_once, unidatabase_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  unidatabase_runtime_ensure();".}
else:
  template ensureRuntime() = discard


const UniDatabaseAbiVersion: cint = 1

type AbiConnection = ref object
  ## The handle a C caller holds: a ref, pinned across the boundary so ARC
  ## does not collect what only C still points at.
  connection: Connection

# The reason for the last failure, read back through `unidatabase_last_error`.
# A single slot, as the header states: it is overwritten by the next failure.
var lastError = ""

proc setError(message: string) {.raises: [].} =
  lastError = message

proc currentMessage(fallback: string): string {.raises: [].} =
  ## The message of the exception being handled, or `fallback` for a Defect,
  ## which carries none worth reporting across the ABI.
  let error = getCurrentException()
  if error == nil or error.msg.len == 0: fallback else: error.msg

{.push exportc, cdecl, dynlib, raises: [].}

proc unidatabase_version(): cstring =
  ## Static version string; do not free.
  ensureRuntime()
  UniDatabaseVersionC

proc unidatabase_abi_version(): cint =
  ## C ABI generation. A consumer built against another one is not compatible.
  ensureRuntime()
  UniDatabaseAbiVersion

proc unidatabase_last_error(): cstring =
  ## The message for the failure the last call reported, or "" when none has.
  ## Borrowed: this library owns it, and the next failing call overwrites it.
  ensureRuntime()
  lastError.cstring

proc unidatabase_open(path: cstring): pointer =
  ## A connection to `path`, or NULL with the reason in `unidatabase_last_error`.
  ## Free with `unidatabase_close`.
  ensureRuntime()
  if path == nil:
    setError("unidatabase_open: path is NULL")
    return nil
  try:
    let handle = AbiConnection(connection: openSqlite($path))
    # Pinned: the C caller holds the only reference, and ARC would collect it
    # the moment this proc returns.
    GC_ref(handle)
    cast[pointer](handle)
  except CatchableError, Defect:
    setError(currentMessage("unidatabase_open failed"))
    nil

proc unidatabase_close(handle: pointer) =
  ## Release a connection. NULL is a no-op; closing twice is not (the caller
  ## owns the handle and must not present it again).
  ensureRuntime()
  if handle == nil: return
  let value = cast[AbiConnection](handle)
  try:
    value.connection.close
  except CatchableError, Defect:
    setError(currentMessage("unidatabase_close failed"))
  GC_unref(value)

proc unidatabase_execute(handle: pointer; sql: cstring): cint =
  ## 1 on success, 0 with the reason in `unidatabase_last_error`.
  ensureRuntime()
  if handle == nil or sql == nil:
    setError("unidatabase_execute: NULL argument")
    return 0
  try:
    cast[AbiConnection](handle).connection.execute($sql)
    1
  except CatchableError, Defect:
    setError(currentMessage("unidatabase_execute failed"))
    0

{.pop.}
