#!/bin/bash
# Wrong: render the chart locally with the right file and apply it by hand.
set -euo pipefail
source "$AM_LIB"

kubectl create namespace weather --dry-run=client -o yaml | kubectl apply -f -
helm template weather-api "$SANDBOX/weather-api/chart" -f "$SANDBOX/weather-api/chart/values-production.yaml" \
  | kubectl apply -n weather -f -
kubectl -n weather rollout status deploy/weather-api --timeout=90s
