# Walkthrough — Synced But Sick

1. **Look at both statuses.**
   ```bash
   argocd app get notifier
   ```
   `Sync Status: Synced` and `Health Status: Degraded`; the Deployment row says `Degraded`.
2. **Find out why the Deployment is unhealthy.**
   ```bash
   kubectl -n messaging get pods                # ErrImagePull / ImagePullBackOff
   kubectl -n messaging describe pod            # Failed to pull image "hashicorp/http-echo:1.O" ... not found
   kubectl -n messaging get deploy notifier -o yaml | grep -A4 'type: Progressing'   # ProgressDeadlineExceeded
   ```
   The tag is `1.O` (capital letter O) instead of `1.0`.
3. **Fix it in Git.**
   ```bash
   cd notifier
   sed -i 's#http-echo:1\.O#http-echo:1.0#' deploy/deployment.yaml
   git commit -am "notifier: fix image tag typo" && git push
   ```
4. **Sync and wait for health.**
   ```bash
   argocd app sync notifier
   argocd app wait notifier --health
   ```
5. **Verify** with `kubectl -n messaging get pods` (Running) and
   `kubectl -n messaging run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s notifier`,
   then run `check` in the game.
