#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Local mirror of the CI spdx job: every tracked Nim/C/Python source must carry
# an SPDX-License-Identifier header within its first 5 lines (5, not 1, so a
# shebang or a `# cython:` directive can stay on line 1 — see _core.pyx).
set -eu

cd "$(git rev-parse --show-toplevel)"

missing=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if ! head -n 5 "$f" | grep -q 'SPDX-License-Identifier:'; then
    echo "Missing SPDX-License-Identifier in first 5 lines: $f"
    missing=1
  fi
# `:!src/*/vendor/*` excludes third-party sources kept verbatim: they carry
# their upstream licence, not this repo's, and adding a header would be a local
# edit lost at the next update. Their provenance lives in the vendor README.
done < <(git ls-files -- '*.nim' '*.nims' '*.c' '*.h' '*.py' '*.pyx' \
           ':!:src/*/vendor/*')

exit "$missing"
