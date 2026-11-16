#!/bin/bash
# Wrong: sync the instances again. The CRD still does not exist, the sync fails the same way.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync sensor-hub --timeout 60 || true
