#!/bin/bash
# Correct too: the kustomize.images override written into the Application YAML.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application ticket-desk --type merge -p '{"spec":{"source":{"kustomize":{"images":["ticket-desk-web=traefik/whoami:v1.10"]}}}}'
am_app_refresh ticket-desk
am_argocd app sync ticket-desk --timeout 120
am_wait_app ticket-desk sync=Synced health=Healthy --timeout 120
kubectl -n desk rollout status deploy/ticket-desk --timeout=90s
