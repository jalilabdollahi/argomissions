# Walkthrough - Values Not Found

1. **Read the error.**
   ```bash
   argocd app get weather-api
   ```
   `Sync Status: Unknown` and a ComparisonError: Helm was started with
   `--values <path to cached source>/chart/values-prod.yaml` and the file is missing.
2. **Compare with Git.**
   ```bash
   ls weather-api/chart          # values.yaml  values-production.yaml  Chart.yaml  templates/
   helm template weather-api weather-api/chart -f weather-api/chart/values-prod.yaml    # same error locally
   helm template weather-api weather-api/chart -f weather-api/chart/values-production.yaml   # works
   ```
3. **Fix - option A, change the Application** (the file name in Git is the production one):
   ```bash
   argocd app set weather-api --values values-production.yaml
   ```
   The old `values-prod.yaml` entry is replaced. Then `argocd app sync weather-api` deploys the chart.
   **Option B, change Git**: `git mv chart/values-production.yaml chart/values-prod.yaml`, commit, push.
4. **Do not** use `--ignore-missing-value-files`: it makes the error vanish, the Application turns green, and
   the chart renders with `values.yaml` only (1 replica, "dev (defaults)").
5. **Verify.**
   ```bash
   argocd app get weather-api     # Synced, Healthy
   kubectl -n weather get deploy  # 2/2
   kubectl -n weather run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s weather-api
   ```
   Then run `check` in the game.
