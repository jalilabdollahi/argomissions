#!/bin/bash
# Correct too: the Service also listens on 8080 (port 80 keeps working), so the test as written passes.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/booking-web"
cat >deploy/service.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: booking-web
spec:
  selector: {app: booking-web}
  ports:
  - name: http
    port: 80
    targetPort: 5678
  - name: http-alt
    port: 8080
    targetPort: 5678
YAML
am_player_push . "Service also on 8080"
am_app_refresh booking-web
am_wait_app booking-web rev="$(am_repo_head booking-web)" --timeout 90
am_argocd app sync booking-web --timeout 150
am_wait_app booking-web sync=Synced health=Healthy op=Succeeded --timeout 120
