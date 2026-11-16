#!/bin/bash
# Wrong: delete the ConfigMap by hand. The banner is gone now, but the next failed sync leaves it up again.
set -euo pipefail
source "$AM_LIB"

kubectl -n bookings delete configmap maintenance-flag
