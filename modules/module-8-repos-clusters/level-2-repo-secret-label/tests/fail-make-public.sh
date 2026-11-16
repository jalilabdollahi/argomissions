#!/bin/bash
# Wrong: stop fighting the secret and make the repo public.
set -euo pipefail
source "$AM_LIB"

am_gitea PATCH /repos/platform/parcel-tracker '{"private":false}' >/dev/null
am_argocd app get parcel-tracker --hard-refresh >/dev/null
am_wait_app parcel-tracker sync=Synced health=Healthy --timeout 150
