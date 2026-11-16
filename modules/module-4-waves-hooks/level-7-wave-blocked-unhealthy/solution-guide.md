# Walkthrough — Stuck In Wave 1

1. **Read the operation.**
   ```bash
   argocd app get fleet-tracker --show-operation
   # Phase: Running   Message: waiting for healthy state of apps/Deployment/tracker-api
   ```
   Only the wave-0 resources (tracker-api) have been applied; tracker-web (wave 1) is still on v1.3.
2. **Find why the wave-0 Deployment is not healthy.**
   ```bash
   kubectl -n fleet get pods                       # new tracker-api pod: 0/1 Running
   kubectl -n fleet get events --field-selector reason=Unhealthy
   # Readiness probe failed: ... :8080/healthz: connect: connection refused
   grep -n -B2 -A3 readinessProbe fleet-tracker/deploy/api.yaml
   ```
   The container listens on 5678 (`-listen=:5678`), the probe asks 8080.
3. **Fix the probe in Git.**
   ```bash
   cd fleet-tracker
   sed -i.bak 's/port: 8080/port: 5678/' deploy/api.yaml && rm deploy/api.yaml.bak
   git commit -am "tracker-api: probe the container port" && git push
   ```
4. **Free the stuck operation, then sync the new head.** A running operation is pinned to the revision it
   started with, so it keeps waiting for the old manifests.
   ```bash
   argocd app terminate-op fleet-tracker
   argocd app get fleet-tracker --refresh
   argocd app sync fleet-tracker
   ```
5. **Verify.** `argocd app get fleet-tracker` is Synced/Healthy, wave 1 is applied, and
   `kubectl -n fleet get deploy` shows both Deployments ready.
