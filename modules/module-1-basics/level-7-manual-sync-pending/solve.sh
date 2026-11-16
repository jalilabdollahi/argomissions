#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app diff search-api || true     # exit code 1 simply means "there is a diff"
am_argocd app sync search-api --timeout 120
am_argocd app wait search-api --health --timeout 120
