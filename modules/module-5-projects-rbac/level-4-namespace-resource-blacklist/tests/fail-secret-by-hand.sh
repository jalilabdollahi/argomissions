#!/bin/bash
# Wrong (partial): the Secret created by hand, but Git still renders it, so the sync is still refused.
set -euo pipefail
source "$AM_LIB"

kubectl -n mailroom create secret generic relay-credentials --from-literal=token=relay-token-7f3a
am_argocd app sync mail-relay --timeout 120 || true
