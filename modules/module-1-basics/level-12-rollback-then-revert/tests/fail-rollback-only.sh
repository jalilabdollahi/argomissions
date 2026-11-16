#!/bin/bash
# Wrong: `argocd app rollback` brings the old release back, but Git still ends with the bad commit.
set -euo pipefail
source "$AM_LIB"

am_argocd app history reports
am_argocd app rollback reports 0 --timeout 120
am_wait_app reports sync=OutOfSync health=Healthy --timeout 120
