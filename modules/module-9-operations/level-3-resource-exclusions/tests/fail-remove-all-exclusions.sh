#!/bin/bash
# Wrong (too lazy): the exclusions are replaced by a rule that hides nothing useful AND hides workloads.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"resource.exclusions":"- apiGroups: [\"*\"]\n  kinds: [\"Deployment\", \"ReplicaSet\"]\n  clusters: [\"*\"]\n"}}'
sleep 5
am_app_refresh lexicon-site normal
sleep 5
