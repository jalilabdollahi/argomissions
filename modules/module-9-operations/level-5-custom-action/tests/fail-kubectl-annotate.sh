#!/bin/bash
# Wrong: the laptop way. The annotation is there, but Argo CD has no button for it.
set -euo pipefail
source "$AM_LIB"

kubectl -n ferry annotate deploy/ferry-booking ferry.argomissions.io/maintenance=on --overwrite
