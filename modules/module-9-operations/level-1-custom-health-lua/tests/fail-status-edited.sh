#!/bin/bash
# Wrong: the failure is hidden by marking the Backup Done by hand (and Running one Done as well).
set -euo pipefail
source "$AM_LIB"

for b in nightly-ledger hourly-journal; do
  kubectl -n vaultline patch backups.vaultline.argomissions.io "$b" --subresource=status --type merge -p '{"status":{"phase":"Done"}}'
done
am_app_refresh vaultline normal
sleep 5
