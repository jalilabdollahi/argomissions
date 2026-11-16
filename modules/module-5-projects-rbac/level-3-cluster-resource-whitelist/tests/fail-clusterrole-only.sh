#!/bin/bash
# Wrong (partial): ClusterRole allowed, ClusterRoleBinding forgotten; the sync still fails.
set -euo pipefail
source "$AM_LIB"

am_argocd proj allow-cluster-resource radar rbac.authorization.k8s.io ClusterRole
am_argocd app sync radar-agent --timeout 120 || true
