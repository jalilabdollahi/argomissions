#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=sensor-hub
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# The declared policy must keep deploying by itself (automated) and keep trying long enough.
[ "$(am_app "$APP" '{.spec.syncPolicy.automated}')" != "" ] || am_fail "Application '$APP' no longer syncs automatically"
am_app_json "$APP" | jq -c '.spec.syncPolicy.retry // {}' > "$AM_TMP/retry.json"
window="$("$AM_PYTHON" - "$AM_TMP/retry.json" <<'PY'
import json, re, sys
r = json.load(open(sys.argv[1]))
def secs(v, default):
    if not v:
        return default
    total = 0
    for n, u in re.findall(r"(\d+(?:\.\d+)?)([hms])", str(v)):
        total += float(n) * {"h": 3600, "m": 60, "s": 1}[u]
    return total or default
if not r:
    print(0); sys.exit()
limit = int(r.get("limit", 0))
b = r.get("backoff") or {}
d, f, m = secs(b.get("duration"), 5), float(b.get("factor", 2) or 2), secs(b.get("maxDuration"), 180)
if limit < 0:
    print(99999); sys.exit()
print(int(sum(min(d * f ** i, m) for i in range(limit))))
PY
)"
[ "$window" -ge 300 ] || am_fail "Automated sync of '$APP' gives up after about ${window}s of retrying; the sensor CRD can take up to five minutes to show up" "$AM_TMP/retry.json"
am_ok "Retry policy keeps trying for about ${window}s"

am_require_app_at_head "$APP" sensor-hub
head="$(am_repo_head sensor-hub)"
[ "$(am_app "$APP" '{.status.operationState.phase}')" = Succeeded ] \
  && [ "$(am_app "$APP" '{.status.operationState.syncResult.revision}')" = "$head" ] \
  || am_fail "No sync of '$APP' has completed at ${head:0:7}"

kubectl -n iot-edge get sensorprofile edge-default >/dev/null 2>&1 || am_fail "SensorProfile edge-default does not exist in namespace iot-edge"
am_ok "SensorProfile edge-default exists"
am_wait_rollout deploy/sensor-hub iot-edge 60s
body="$(am_http http://sensor-hub.iot-edge iot-edge)" || am_fail "Service sensor-hub in namespace iot-edge does not answer"
[ "$body" = "sensor-hub v2.0" ] || am_fail "Service sensor-hub answers '$body'"
am_pass "sensor-hub is deployed, and its sync policy now survives a late CRD"
