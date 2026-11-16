#!/bin/bash
# Wrong: remove the stray files in the workspace clone but never commit or push.
set -euo pipefail
source "$AM_LIB"

rm -f "$SANDBOX/docs-portal/deploy/Chart.yaml" "$SANDBOX/docs-portal/deploy/values.yaml"
am_argocd app get docs-portal --refresh >/dev/null
