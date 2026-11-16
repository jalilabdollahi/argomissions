#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd proj allow-cluster-resource radar rbac.authorization.k8s.io ClusterRole
am_argocd proj allow-cluster-resource radar rbac.authorization.k8s.io ClusterRoleBinding
am_argocd app sync radar-agent --timeout 120
am_argocd app wait radar-agent --health --timeout 120
