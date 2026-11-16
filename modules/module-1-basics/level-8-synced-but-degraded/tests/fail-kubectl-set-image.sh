#!/bin/bash
# Wrong: the live Deployment is patched; Git still has the broken tag and the Application is OutOfSync.
set -euo pipefail
source "$AM_LIB"

kubectl -n messaging set image deploy/notifier gateway=hashicorp/http-echo:1.0
kubectl -n messaging rollout status deploy/notifier --timeout=90s
