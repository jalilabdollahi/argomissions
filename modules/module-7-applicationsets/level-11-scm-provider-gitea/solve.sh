#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The Secret holds the token under `token`; the ApplicationSet asked for `access-token`.
sed -i.bak 's/key: access-token/key: token/' "$SANDBOX/mesh-appset.yaml"
rm -f "$SANDBOX/mesh-appset.yaml.bak"
kubectl apply -f "$SANDBOX/mesh-appset.yaml"
for r in pinger quill ember; do am_wait_app "mesh-$r" sync=Synced health=Healthy --timeout 180; done
