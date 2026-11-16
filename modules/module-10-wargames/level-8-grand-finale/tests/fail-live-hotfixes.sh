#!/bin/bash
# Wrong: everything is "fixed" on the cluster (projects, ApplicationSet, core sync option) and nothing is pushed.
# The root heals the ApplicationSet back to what Git says and does not own the projects.
set -euo pipefail
source "$AM_LIB"
cd "$SANDBOX/meridian-platform"
for p in core edge; do
  sed 's/namespace: meridian-south$/namespace: meridian-south\n  - server: https:\/\/kubernetes.default.svc\n    namespace: meridian-harbor/' "bootstrap/projects/meridian-$p.yaml" | kubectl apply -f - >/dev/null
done
sed 's/{{district}}/{{.district}}/' bootstrap/edge-appset.yaml | kubectl apply -f - >/dev/null
am_argocd app set meridian-core --sync-option CreateNamespace=true >/dev/null
sleep 40
