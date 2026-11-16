#!/bin/bash
# Wrong: drop the second source and paste the values into the Application. It runs the right text,
# but the values no longer come from the environment repo.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application pricing --type json -p '[
 {"op":"remove","path":"/spec/sources/1"},
 {"op":"replace","path":"/spec/sources/0/helm","value":{"values":"replicas: 2\ntext: \"pricing v2.4 prod\"\n"}}]'
am_argocd app get pricing --refresh >/dev/null
am_argocd app sync pricing --timeout 120
am_wait_app pricing sync=Synced health=Healthy --timeout 120
