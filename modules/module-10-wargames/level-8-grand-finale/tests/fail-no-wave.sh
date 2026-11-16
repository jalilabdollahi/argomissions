#!/bin/bash
# Wrong: everything works today but the AppProjects have no sync-wave: a fresh bootstrap would race.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
NO_WAVE=1 fix_git
finish "bootstrap fixes (no waves)"
