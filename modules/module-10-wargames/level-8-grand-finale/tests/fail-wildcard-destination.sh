#!/bin/bash
# Wrong: harbor is admitted by opening the edge project to every namespace.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
WILDCARD=1 fix_git
finish "bootstrap fixes (wildcard destination)"
