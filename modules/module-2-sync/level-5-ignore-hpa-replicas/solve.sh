#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app patch quote-api --type merge --patch '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}],
  "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
am_wait_app quote-api sync=Synced health=Healthy --timeout 150
