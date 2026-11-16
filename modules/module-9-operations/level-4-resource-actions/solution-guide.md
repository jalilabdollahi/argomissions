# Walkthrough — Restart Without kubectl

1. **Confirm the symptom.**
   ```bash
   argocd app get tollbooth                                  # Synced, Healthy
   kubectl -n tollbooth get cm tollbooth-rates -o jsonpath='{.data.RATE_CARD}'   # 2025-Q4
   kubectl -n tollbooth run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s tollbooth   # 2025-Q3
   ```
   Environment variables from a ConfigMap are read once, when the container starts.
2. **List the actions Argo CD offers for the Deployment.**
   ```bash
   argocd app actions list tollbooth --kind Deployment --resource-name tollbooth
   ```
   Output: `scale`, `pause`, `restart` (and `resume`, disabled until the Deployment is paused).
3. **Run the restart.**
   ```bash
   argocd app actions run tollbooth restart --kind Deployment --resource-name tollbooth
   ```
   (UI: open the application, click the Deployment, **Actions** menu, **restart**.) The action sets the
   annotation `kubectl.kubernetes.io/restartedAt` on the pod template, so the Deployment rolls out new pods.
4. **Verify.**
   ```bash
   kubectl -n tollbooth rollout status deploy/tollbooth
   argocd app get tollbooth       # still Synced: Git has no such annotation, and Argo CD does not diff fields Git leaves unset
   ```
   The Service now answers `tollbooth rates 2025-Q4`.
