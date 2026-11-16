#!/bin/bash
# Wrong: patch the live Deployment. The pods start, but the Application is OutOfSync and Git and the Application still say nginx.
set -euo pipefail
source "$AM_LIB"

kubectl -n desk set image deploy/ticket-desk web=traefik/whoami:v1.10
kubectl -n desk rollout status deploy/ticket-desk --timeout=90s
