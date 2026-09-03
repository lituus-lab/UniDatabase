// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
// The documented C surface, exercised end to end: open, run statements, close.
// Nothing else builds this file, so it is where a drifted header shows up.
#include <stdio.h>
#include <stdlib.h>
#include "UniDatabase.h"

int main(void) {
  printf("UniDatabase %s (ABI %d)\n", unidatabase_version(),
         unidatabase_abi_version());

  const char *path = "demo.sqlite";
  remove(path); /* Start from nothing, so a rerun says the same thing. */

  void *database = unidatabase_open(path);
  if (database == NULL) {
    printf("FAIL: cannot open %s: %s\n", path, unidatabase_last_error());
    return 1;
  }

  if (!unidatabase_execute(database, "CREATE TABLE notes(body TEXT)") ||
      !unidatabase_execute(database, "INSERT INTO notes VALUES ('ok')")) {
    printf("FAIL: %s\n", unidatabase_last_error());
    unidatabase_close(database);
    return 1;
  }
  printf("created a table and inserted a row\n");

  /* A statement the engine refuses leaves its reason behind, and the
     connection stays usable. */
  if (unidatabase_execute(database, "THIS IS NOT SQL")) {
    printf("FAIL: a bad statement was accepted\n");
    unidatabase_close(database);
    return 1;
  }
  printf("a bad statement was refused: %s\n", unidatabase_last_error());

  unidatabase_close(database);
  printf("closed\n");
  return 0;
}
