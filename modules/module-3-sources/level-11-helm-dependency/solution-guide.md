# Walkthrough — Missing Subchart

1. **Read the error.**
   ```bash
   argocd app get notify
   ```
   `ComparisonError: ... helm dependency build failed ... Error: directory ../notify-commons not found`.
2. **Compare with the repo.**
   ```bash
   ls notify-platform/charts            # notify  notify-common   (no "s")
   cat notify-platform/charts/notify/Chart.yaml
   ```
   The dependency says `repository: file://../notify-commons`, relative to `charts/notify`.
3. **Reproduce locally (optional).**
   ```bash
   helm dependency build notify-platform/charts/notify
   ```
4. **Fix the path** in `charts/notify/Chart.yaml`: `repository: file://../notify-common`. (Renaming the
   directory to `notify-commons` is equally valid.)
5. **Push, refresh, sync.**
   ```bash
   cd notify-platform && git commit -am "fix notify-common dependency path" && git push
   argocd app get notify --refresh
   argocd app sync notify
   argocd app wait notify --health
   ```
6. **Verify.** `kubectl -n notifications get deploy,pods` shows 2 pods; the service answers
   `notify v4.7 (email)`. Then run `check`. Do not commit the generated `charts/` or `Chart.lock` files:
   Argo CD builds them for you.
