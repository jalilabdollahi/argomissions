#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed payroll-engine "$LEVEL_DIR/repo" "payroll-engine v4.0"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh payroll-engine
am_wait_app payroll-engine sync=OutOfSync --timeout 120 || { echo "setup: payroll-engine never became OutOfSync"; exit 1; }
am_app_sync_now payroll-engine
am_wait_app payroll-engine op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v4.0 did not sync"; exit 1; }

# Release v4.1: a migration Job (PreSync) plus the Role change it needs (a regular resource).
am_repo_commit payroll-engine "$LEVEL_DIR/assets/release" "release v4.1: ledger-migrate pre-sync job, migrator may create configmaps"
head="$(am_repo_head payroll-engine)"
am_app_refresh payroll-engine
am_wait_app payroll-engine sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see v4.1"; exit 1; }
am_app_sync_now payroll-engine "$head"
am_wait_app payroll-engine op=Failed --timeout 120 || { echo "setup: the v4.1 sync did not fail"; exit 1; }
am_setup_assert "the migration was refused" bash -c '! kubectl -n payroll get configmap schema-version'
am_workspace_clone payroll-engine
