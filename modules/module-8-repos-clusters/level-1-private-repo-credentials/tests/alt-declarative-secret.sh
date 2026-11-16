#!/bin/bash
# Correct too: the repository declared as a labelled Secret.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: repo-vault-ui
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $(am_repo_url vault-ui)
  username: argo-reader
  password: reader-pass-7Q2x
YAML
am_argocd app get vault-ui --hard-refresh >/dev/null
am_wait_app vault-ui sync=Synced health=Healthy --timeout 150
