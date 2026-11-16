#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app patch profile-svc --type merge --patch '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","name":"profile-svc","jsonPointers":["/metadata/labels/cost-center"]}]}}'
am_wait_app profile-svc sync=Synced health=Healthy --timeout 120
