#!/bin/bash
# Wrong: scale the Deployment by hand. The production text is still missing and the app is OutOfSync.
set -euo pipefail
source "$AM_LIB"

kubectl -n search scale deploy/search-suggest --replicas=3
kubectl -n search rollout status deploy/search-suggest --timeout=90s
