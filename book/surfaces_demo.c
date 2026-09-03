/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* Run by book/surfaces.nim during the book build; its output is the page's. */
#include <stdio.h>
#include "UniDatabase.h"

int main(void) {
  printf("unidatabase_version()            = %s\n", unidatabase_version());
  printf("unidatabase_fibonacci(10)        = %lld\n", unidatabase_fibonacci(10));
  printf("unidatabase_fibonacci(-1)        = %lld   (clamped, not an error)\n",
         unidatabase_fibonacci(-1));
  printf("unidatabase_fibonacci(200)       = %lld   (clamped to n = %d)\n",
         unidatabase_fibonacci(200), UNIDATABASE_FIB_MAX_N);
  return 0;
}
