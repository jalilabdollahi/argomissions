# Walkthrough — The Drift That Stays

1. **See the drift.**
   ```bash
   argocd app get pricing-api
   argocd app diff pricing-api
   ```
   The app is `OutOfSync`; the diff shows `replicas: 2` (Git) against `5` (live) and
   `max-discount-percent: "5"` against `"40"`. Sync Policy says `Automated` — but without `SelfHeal`.
2. **Why automated sync does nothing.** It starts a sync when Git changes. Drift in the cluster does not change
   Git, so there is nothing new to deploy.
3. **Enable self-heal.**
   ```bash
   argocd app set pricing-api --self-heal
   ```
   (UI: Details → Sync Policy → enable **Self Heal**; YAML: `syncPolicy.automated.selfHeal: true`.)
4. **Watch.** Argo CD notices the existing drift on its next reconcile and syncs: replicas back to 2, the
   ConfigMap back to 5. `argocd app get pricing-api` is `Synced`.
5. **Verify.** Try `kubectl -n pricing scale deploy/pricing-api --replicas=4`: a few seconds later it is back to 2.
   Then run `check` in the game.
