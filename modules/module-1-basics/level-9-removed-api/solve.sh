#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/billing"
sed -i.bak 's#policy/v1beta1#policy/v1#' deploy/pdb.yaml && rm deploy/pdb.yaml.bak
am_player_push "$SANDBOX/billing" "pdb: policy/v1beta1 -> policy/v1"
am_argocd app sync billing --timeout 120
am_argocd app wait billing --health --timeout 120
