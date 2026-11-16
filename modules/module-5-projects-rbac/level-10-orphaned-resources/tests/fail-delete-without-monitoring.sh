#!/bin/bash
# Wrong: the stray Deployment is deleted by hand, but the project never learns to warn about orphans.
set -euo pipefail
source "$AM_LIB"

kubectl -n search delete deployment legacy-indexer
