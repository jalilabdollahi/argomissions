#!/bin/bash
# Correct too: instead of reverting, the typo is corrected in a new commit; automation restored through the Application manifest.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application orbit-control --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl -n argocd patch appproject orbit --type json -p '[{"op":"add","path":"/spec/sourceRepos/-","value":"'"$(am_repo_url orbit-services)"'"}]'
cd "$SANDBOX/orbit-control"
sed -i.bak 's#path: service/\*#path: services/*#' appsets/orbit-fleet.yaml && rm appsets/orbit-fleet.yaml.bak
"$AM_PYTHON" - <<'PY'
p = "appsets/orbit-fleet.yaml"
s = open(p).read().replace("  generators:\n", "  syncPolicy:\n    preserveResourcesOnDeletion: true\n  generators:\n", 1)
open(p, "w").write(s)
PY
am_player_push . "Fix the generator path, protect the fleet"
am_argocd app get orbit-control --refresh >/dev/null
am_wait_app orbit-control sync=Synced --timeout 150
for s in ingest rollup alerts; do
  am_wait 120 kubectl -n argocd get application "orbit-$s"
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 180
done
