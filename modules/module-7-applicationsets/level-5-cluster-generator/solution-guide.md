# Walkthrough — Label Me In

1. **The set is happy.**
   ```bash
   argocd appset get quota-fleet     # "All applications have been generated successfully", no Applications
   ```
2. **Read the selector.**
   ```bash
   kubectl -n argocd get applicationset quota-fleet -o jsonpath='{.spec.generators[0].clusters}'
   # {"selector":{"matchLabels":{"env":"staging"}}}
   ```
3. **Read what the generator can match.** The labels come from the cluster Secrets:
   ```bash
   argocd cluster list
   kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster --show-labels
   ```
   `cluster-staging` has `team=platform` but no `env`. The built-in `in-cluster` entry has no Secret and no labels.
4. **Label the cluster secret.**
   ```bash
   kubectl -n argocd label secret cluster-staging env=staging
   ```
5. **Watch the Application appear.** The controller watches cluster secrets, so it reacts at once:
   ```bash
   argocd app list                  # quota-staging
   argocd app wait quota-staging --health
   ```
6. **Verify** `quota-api` answers `quota-api v3` in namespace `quota`, then run `check` in the game.

Removing the selector would also generate `quota-in-cluster`: wrong, it is not staging.
