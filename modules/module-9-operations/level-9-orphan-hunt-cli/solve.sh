#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Forensics: which revision first served USD?
am_argocd app history rates-service
for id in $(am_argocd app history rates-service -o id); do
  rev="$(am_app_json rates-service | jq -r --argjson id "$id" '.status.history[] | select(.id==$id) | .revision')"
  if am_argocd app manifests rates-service --revision "$rev" | grep -A1 'BASE_CURRENCY' | grep -q USD; then
    echo "first USD revision: history id $id ($rev)"; break
  fi
done
cd "$SANDBOX/rates-service"
git pull -q
sed -i.bak '/name: BASE_CURRENCY/{n;s/"USD"/"EUR"/;}' deploy/deployment.yaml
rm -f deploy/deployment.yaml.bak
am_player_push "$SANDBOX/rates-service" "Restore BASE_CURRENCY=EUR"
am_argocd app get rates-service --refresh >/dev/null
head="$(am_repo_head rates-service)"
am_wait_app rates-service sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 150
