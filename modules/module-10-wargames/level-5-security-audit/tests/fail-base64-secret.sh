#!/bin/bash
# Wrong: findings 1, 3, 4 are fixed; the "plaintext" Secret is re-written as base64 `data:` with the same password.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
fix_access; fix_creds; fix_project
cd "$SANDBOX/custody-api"; git pull -q
cat >deploy/db-secret.yaml <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: custody-db
type: Opaque
data:
  password: $(printf '%s' 'Summer2024!db' | base64)
YAML
push_api "db secret: no more plaintext, base64 encoded"
settle
