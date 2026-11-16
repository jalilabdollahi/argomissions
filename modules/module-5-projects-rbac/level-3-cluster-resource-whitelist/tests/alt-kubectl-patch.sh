#!/bin/bash
# Correct too: the whitelist edited as YAML with kubectl.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject radar --type merge -p '{"spec":{"clusterResourceWhitelist":[
  {"group":"rbac.authorization.k8s.io","kind":"ClusterRole"},
  {"group":"rbac.authorization.k8s.io","kind":"ClusterRoleBinding"}]}}'
sleep 3
am_argocd app sync radar-agent --timeout 120
am_argocd app wait radar-agent --health --timeout 120
