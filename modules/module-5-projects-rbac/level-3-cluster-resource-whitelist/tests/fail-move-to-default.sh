#!/bin/bash
# Wrong: move the app to `default`, which allows every cluster resource.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application radar-agent --type merge -p '{"spec":{"project":"default"}}'
am_argocd app sync radar-agent --timeout 120
am_argocd app wait radar-agent --health --timeout 120
