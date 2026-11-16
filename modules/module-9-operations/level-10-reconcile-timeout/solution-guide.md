# Walkthrough — Why So Slow?

1. **Confirm Argo CD is not looking.**
   ```bash
   argocd app get lobby-board                     # Synced, at the commit of v1.0
   git -C lobby-board fetch && git -C lobby-board log --oneline origin/main   # v1.1 is there
   kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.timeout\.reconciliation}'   # 24h
   ```
   A hard refresh (`argocd app get lobby-board --refresh`) would deploy v1.1 right now, but it is a one-off:
   the next push waits 24 hours again.
2. **Fix the value.** The default is `180s`; this game uses `60s`; anything from 30 s to 10 min is reasonable
   when webhooks are not available.
   ```bash
   kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"180s"}}'
   ```
3. **Restart the components that read it.** The value is injected as the environment variable
   `ARGOCD_RECONCILIATION_TIMEOUT` of the application controller (how often an app is re-compared) and of the
   repo-server (how long it trusts a cached branch-to-commit lookup). Environment variables are read at start:
   ```bash
   kubectl -n argocd rollout restart statefulset/argocd-application-controller deploy/argocd-repo-server
   kubectl -n argocd rollout status statefulset/argocd-application-controller
   kubectl -n argocd rollout status deploy/argocd-repo-server
   ```
   Restarting only one of them leaves the other on 24h.
4. **Refresh once** so you do not wait for the first tick, and verify:
   ```bash
   argocd app get lobby-board --refresh
   kubectl -n argocd exec argocd-application-controller-0 -- printenv ARGOCD_RECONCILIATION_TIMEOUT
   ```
   The app is now at v1.1. Run `check`.
