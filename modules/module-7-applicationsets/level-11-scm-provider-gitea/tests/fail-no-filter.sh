#!/bin/bash
# Wrong: the token key is fixed, but the filter is removed "to be sure", so wiki-notes becomes an Application too.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset mesh-fleet --type json -p '[
  {"op":"replace","path":"/spec/generators/0/scmProvider/gitea/tokenRef/key","value":"token"},
  {"op":"remove","path":"/spec/generators/0/scmProvider/filters"}]'
wiki_app() { am_app_exists wiki-notes; }
am_wait 90 wiki_app
for r in pinger quill ember; do am_wait_app "mesh-$r" sync=Synced health=Healthy --timeout 180; done
