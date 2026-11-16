#!/bin/bash
# Wrong: the live Deployment patched by hand; Git still says USD and the Application drifts.
set -euo pipefail
source "$AM_LIB"

kubectl -n fx-rates set env deploy/rates-service BASE_CURRENCY=EUR
kubectl -n fx-rates rollout status deploy/rates-service --timeout=90s
