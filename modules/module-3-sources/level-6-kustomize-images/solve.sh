#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set ticket-desk --kustomize-image ticket-desk-web=traefik/whoami:v1.10
am_argocd app sync ticket-desk --timeout 120
am_argocd app wait ticket-desk --health --timeout 120
kubectl -n desk rollout status deploy/ticket-desk --timeout=90s
