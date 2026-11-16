#!/bin/bash
# Wrong: a different built-in action (scale to the same size via `pause`/`resume` style) does not replace the pods.
set -euo pipefail
source "$AM_LIB"

am_argocd app actions run tollbooth pause --kind Deployment --resource-name tollbooth
am_argocd app actions run tollbooth resume --kind Deployment --resource-name tollbooth
am_wait_app tollbooth sync=Synced health=Healthy --timeout 120
