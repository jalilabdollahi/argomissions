# Walkthrough — Values From Another Repo

1. **Read the error.**
   ```bash
   argocd app get pricing
   ```
   Conditions: `ComparisonError ... source referenced "$values", which is not one of the available sources ($env)`.
2. **Inspect the sources.**
   ```bash
   kubectl -n argocd get application pricing -o jsonpath='{.spec.sources}' | jq
   ```
   Source 0 (the chart) has `valueFiles: ["$values/prod/values.yaml"]`. Source 1 (pricing-env) has `ref: env`.
   A `$name` prefix is resolved against the `ref` of another source, so `$values` finds nothing.
3. **Make the names match.** Either rename the ref:
   ```bash
   kubectl -n argocd patch application pricing --type json \
     -p '[{"op":"replace","path":"/spec/sources/1/ref","value":"values"}]'
   ```
   or change the valueFiles entry to `$env/prod/values.yaml`.
4. **Sync and verify.**
   ```bash
   argocd app get pricing --refresh
   argocd app sync pricing
   argocd app wait pricing --health
   kubectl -n pricing get deploy,pods      # 2 replicas
   ```
   The service answers `pricing v2.4 prod`. Then run `check` in the game.
