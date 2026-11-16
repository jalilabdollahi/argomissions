#!/bin/bash
# Wrong: "just sync it" — Git still says 1 replica, so the hotfix is reverted.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync checkout --timeout 120
am_argocd app wait checkout --health --timeout 120
