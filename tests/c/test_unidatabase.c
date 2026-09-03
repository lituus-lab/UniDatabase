/* SPDX-License-Identifier: Apache-2.0 */
#include "UniDatabase.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
  void *db = unidatabase_open("/tmp/unidatabase-c-consumer.sqlite");
  assert(db != 0);
  assert(unidatabase_execute(db, "CREATE TABLE IF NOT EXISTS t(value TEXT)") == 1);
  unidatabase_close(db);
  return 0;
}
