#!/bin/bash
# Correct too: the PDB is rewritten for policy/v1 with a different (still valid) budget.
set -euo pipefail
source "$AM_LIB"

cat >"$SANDBOX/billing/deploy/pdb.yaml" <<'YAML'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: billing
spec:
  maxUnavailable: 1
  selector:
    matchLabels: {app: billing}
YAML
am_player_push "$SANDBOX/billing" "pdb: rewrite for policy/v1"
am_argocd app sync billing --timeout 120
am_argocd app wait billing --health --timeout 120
