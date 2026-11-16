#!/bin/bash
# Also correct: tell Argo CD explicitly that this is a directory source (any directory setting does that).
set -euo pipefail
source "$AM_LIB"

am_argocd app set docs-portal --directory-recurse
am_app_refresh docs-portal hard
am_wait_app docs-portal sync=Synced health=Healthy --timeout 150
