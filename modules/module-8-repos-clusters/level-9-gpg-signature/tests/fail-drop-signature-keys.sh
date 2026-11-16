#!/bin/bash
# Wrong: stop requiring signatures on the project so the unsigned commit goes through.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject treasury --type json -p '[{"op":"remove","path":"/spec/signatureKeys"}]' >/dev/null
am_argocd app get treasury-core --hard-refresh >/dev/null
am_argocd app sync treasury-core --timeout 120
am_argocd app wait treasury-core --health --timeout 120
