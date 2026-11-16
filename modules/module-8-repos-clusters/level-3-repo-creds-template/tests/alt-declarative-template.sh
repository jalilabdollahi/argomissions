#!/bin/bash
# Correct too: the template as a labelled Secret (trailing slash on the prefix).
set -euo pipefail
source "$AM_LIB"

kubectl apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: creds-platform-org
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: $AM_GIT_INCLUSTER/platform/
  username: argo-reader
  password: reader-pass-1Wm6
YAML
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do am_argocd app get "$r" --hard-refresh >/dev/null; done
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do am_wait_app "$r" sync=Synced health=Healthy --timeout 150; done
