#!/bin/bash
# Wrong: the failing file is deleted from Git, so the sync "works" but the PodDisruptionBudget is gone.
set -euo pipefail
source "$AM_LIB"

git -C "$SANDBOX/billing" rm -q deploy/pdb.yaml
am_player_push "$SANDBOX/billing" "drop the PDB"
am_argocd app sync billing --timeout 120
am_argocd app wait billing --health --timeout 120
