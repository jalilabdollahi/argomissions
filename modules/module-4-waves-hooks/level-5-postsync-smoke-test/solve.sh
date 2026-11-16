#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/booking-web"
kubectl -n booking logs job/booking-web-smoke-test || true
kubectl -n booking get svc booking-web
sed -i.bak 's#http://booking-web:8080/#http://booking-web/#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
am_player_push . "smoke test: call the Service on its real port"
am_app_refresh booking-web
am_wait_app booking-web rev="$(am_repo_head booking-web)" --timeout 90
am_argocd app sync booking-web --timeout 150
am_argocd app wait booking-web --health --timeout 120
