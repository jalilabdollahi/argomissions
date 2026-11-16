#!/bin/bash
# Wrong: avoid SSH altogether by pointing the app at the HTTP URL (repo is private; no credentials for it either).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application fleet-agent --type merge -p "{\"spec\":{\"source\":{\"repoURL\":\"$(am_repo_url fleet-agent)\"}}}"
sleep 5
