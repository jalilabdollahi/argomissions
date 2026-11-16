# Walkthrough — The Hotfix That Flips Back

1. **Look at the child.**
   ```bash
   argocd app get courier-routing
   argocd app history courier-routing
   ```
   `Target: main`. The history shows the hotfix was deployed for a short time and then replaced again.
2. **Look at its owner.** `argocd app get courier-fleet` is `automated` with `selfHeal: true`, and `courier-routing` is
   one of its resources (annotation `argocd.argoproj.io/tracking-id`). `argocd app set` edits the child object in
   the cluster; the root compares it with `apps/api.yaml` in Git, sees a difference and rewrites it.
3. **Do not weaken the root.** Turning self-heal off keeps the hand edit alive but leaves `courier-fleet` OutOfSync,
   and nobody can see in Git what production runs.
4. **Change the file the root owns.**
   ```bash
   cd courier-fleet
   sed -i 's/targetRevision: main/targetRevision: hotfix-routing/' apps/api.yaml
   git commit -am "api: ship hotfix-routing (v2.4.1) until merged" && git push
   ```
5. **Let the root apply it.** `argocd app get courier-fleet --refresh` (or wait up to a minute). The root updates
   the child, the child syncs `hotfix-routing` automatically.
6. **Verify.** `argocd app get courier-routing` shows `Target: hotfix-routing`; the Service answers `courier-routing v2.4.1`.
   Run `check`.
