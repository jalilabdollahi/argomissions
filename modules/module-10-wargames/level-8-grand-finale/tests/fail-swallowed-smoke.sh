#!/bin/bash
# Wrong: the smoke test is made green with `|| true`.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
SWALLOW=1 fix_git
finish "bootstrap fixes (silenced smoke test)"
