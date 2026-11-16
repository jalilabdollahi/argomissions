#!/bin/bash
# Wrong: an exclude pattern that does not match any file ("tests" is a folder, the glob is matched against files).
set -euo pipefail
source "$AM_LIB"

am_argocd app set collector --directory-exclude 'tests'
sleep 15
am_argocd app get collector --refresh >/dev/null
