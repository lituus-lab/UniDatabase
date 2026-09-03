// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include "UniDatabase.h"

int main(void) {
  printf("UniDatabase %s\n", unidatabase_version());
  int ns[] = {0, 1, 10, 20, 50, 90, UNIDATABASE_FIB_MAX_N};
  for (size_t i = 0; i < sizeof(ns) / sizeof(ns[0]); i++)
    printf("fib(%d) = %lld\n", ns[i], unidatabase_fibonacci(ns[i]));
  return 0;
}
