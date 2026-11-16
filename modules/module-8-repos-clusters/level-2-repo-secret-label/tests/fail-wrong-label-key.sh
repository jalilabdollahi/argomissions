#!/bin/bash
# Wrong: another plausible but wrong label value (`repo-creds` is a credential template that needs a prefix URL and
# a different Secret; here the secret-type is still not the one Argo CD reads for a repository entry) – the repo stays unknown.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd label secret repo-parcel-tracker argocd.argoproj.io/secret-type=repos --overwrite
am_argocd app get parcel-tracker --hard-refresh >/dev/null 2>&1 || true
sleep 5
