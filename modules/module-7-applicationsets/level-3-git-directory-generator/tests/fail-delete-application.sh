#!/bin/bash
# Wrong: the unwanted Application is deleted; the ApplicationSet generates it again.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd delete application studio-shared --wait=true
sleep 30
