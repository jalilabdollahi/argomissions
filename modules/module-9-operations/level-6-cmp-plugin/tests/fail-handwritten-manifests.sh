#!/bin/bash
# Wrong: giving up on the plugin and committing plain manifests; the app deploys but nothing is rendered by it.
set -euo pipefail
source "$AM_LIB"

cat >"$SANDBOX/label-printer/deploy/deployment.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: label-printer
spec:
  replicas: 2
  selector:
    matchLabels: {app: label-printer}
  template:
    metadata:
      labels: {app: label-printer}
    spec:
      terminationGracePeriodSeconds: 2
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          imagePullPolicy: IfNotPresent
          args: ["-text=label-printer v2.1"]
---
apiVersion: v1
kind: Service
metadata:
  name: label-printer
spec:
  selector: {app: label-printer}
  ports:
    - port: 80
      targetPort: 5678
YAML
am_player_push "$SANDBOX/label-printer" "Add plain manifests"
am_app_refresh label-printer hard
am_wait_app label-printer sync=Synced health=Healthy --timeout 120
rev="$(am_repo_head label-printer)"
am_wait_app label-printer rev="$rev" op=Succeeded --timeout 120
