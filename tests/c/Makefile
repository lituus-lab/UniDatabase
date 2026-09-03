# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Shell-free: `pwd` and `rm` are unavailable under mingw32-make on Windows.
ifeq ($(origin CC),default)
  ifeq ($(OS),Windows_NT)
    CC := gcc
  else
    CC := cc
  endif
endif

ROOT   := $(CURDIR)/../..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniDatabase.a
# libUniDatabase.a leaves the SQLite entry points unresolved: the engine binds
# the system library rather than vendoring it, so the consumer supplies it.
# SQLite is compiled into libUniDatabase.a, so nothing links -lsqlite3 any more.
# What is left is what SQLite itself calls into, and only where the platform
# keeps it in a separate library: libm and dlopen and pthreads on Linux, libm
# on macOS, nothing on Windows (kernel32 covers it, and MinGW links libm by
# default).
ifeq ($(OS),Windows_NT)
  LIBS :=
else
  UNAME := $(shell uname -s)
  ifeq ($(UNAME),Linux)
    LIBS := -lm -ldl -lpthread
  else
    LIBS := -lm
  endif
endif

ifeq ($(OS),Windows_NT)
  BIN  := test_unidatabase.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := test_unidatabase
  RUN  := ./$(BIN)
  RM_F := rm -f
endif

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): test_unidatabase.c $(ROOT)/include/UniDatabase.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) test_unidatabase.c $(LIB) $(LIBS)
# File target, not phony: `nimble ctest` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)
