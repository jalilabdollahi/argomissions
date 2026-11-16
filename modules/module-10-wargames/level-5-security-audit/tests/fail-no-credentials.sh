#!/bin/bash
# Wrong: the per-repository secrets with the human login are deleted, nothing replaces them; the rest is fixed.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
fix_access; fix_project
kubectl -n argocd delete secret repo-custody-api repo-custody-batch >/dev/null
am_argocd app get custody-api --hard-refresh >/dev/null 2>&1 || true
am_argocd app get custody-batch --hard-refresh >/dev/null 2>&1 || true
am_wait 90 bash -c "kubectl -n argocd get application custody-batch -o json | grep -qiE 'authentication required|not found|ComparisonError'" || true
