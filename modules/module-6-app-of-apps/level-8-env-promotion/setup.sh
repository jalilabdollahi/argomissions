#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed meterhub-service "$LEVEL_DIR/repos/meterhub-service" "meterhub v1.2.0"
am_repo_tag meterhub-service v1.2.0
am_repo_commit meterhub-service "$LEVEL_DIR/assets/rc" "meterhub v1.3.0-rc1 (unfinished, not released)"
am_repo_seed meterhub-gitops "$LEVEL_DIR/repos/meterhub-gitops" "meterhub-gitops: staging and prod roots"
for env in staging prod; do
  am_app_apply "$LEVEL_DIR/assets/root-$env.yaml"
  am_app_refresh "meterhub-env-$env"
done
for env in staging prod; do
  am_wait_app "meterhub-env-$env" sync=Synced health=Healthy --timeout 150 || { echo "setup: meterhub-env-$env not Synced"; exit 1; }
  am_wait_app "meterhub-$env" sync=Synced health=Healthy --timeout 150 || { echo "setup: meterhub-$env not Healthy"; exit 1; }
done
body="$(am_http http://meterhub.meterhub-prod meterhub-prod)" || { echo "setup: prod does not answer"; exit 1; }
[ "$body" = "meterhub v1.3.0-rc1" ] || { echo "setup: prod answers '$body'"; exit 1; }
am_workspace_clone meterhub-gitops
