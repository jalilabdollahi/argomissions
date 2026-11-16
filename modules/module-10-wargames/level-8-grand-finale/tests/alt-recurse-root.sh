#!/bin/bash
# Correct too: the projects stay in bootstrap/projects/ and the root is told to read subfolders.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
KEEP_SUBDIR=1 fix_git
am_argocd app set meridian-root --directory-recurse >/dev/null
finish "bootstrap fixes (root recurses)"
