#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set orders --repo "$(am_repo_url orders)"
am_argocd app sync orders --timeout 120
am_argocd app wait orders --health --timeout 120
