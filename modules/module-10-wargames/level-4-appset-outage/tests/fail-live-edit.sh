#!/bin/bash
# Wrong: the ApplicationSet is edited in the cluster. orbit-control has self-heal again: Git's broken version comes back.
set -euo pipefail
source "$AM_LIB"

am_argocd app set orbit-control --sync-policy automated --auto-prune --self-heal
am_argocd proj add-source orbit "$(am_repo_url orbit-services)"
am_wait_app orbit-control sync=Synced --timeout 120
kubectl -n argocd patch applicationset orbit-fleet --type json \
  -p '[{"op":"replace","path":"/spec/generators/0/git/directories/0/path","value":"services/*"},{"op":"add","path":"/spec/syncPolicy","value":{"preserveResourcesOnDeletion":true}}]'
sleep 60
