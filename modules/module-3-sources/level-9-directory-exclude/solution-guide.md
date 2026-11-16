# Walkthrough — Test Fixtures In Production

1. **Find the source of the junk.**
   ```bash
   kubectl -n telemetry get pods
   argocd app get collector             # lists fixture-loadgen and fixture-fake-source as Synced resources
   find telemetry-agents/deploy -type f # deploy/tests/fixture-*.yaml sit below the recursed path
   ```
2. **Why they are deployed.** The Application has `directory.recurse: true`, so every YAML below `deploy/`
   is rendered, including `deploy/tests/`. CI needs those files in Git, so deleting them is not an option.
3. **Exclude them in the Application.**
   ```bash
   argocd app set collector --directory-exclude 'tests/*'
   ```
   (UI: App Details → Edit → *Directory* → Exclude. YAML: `spec.source.directory.exclude: 'tests/*'`.)
   Alternative: `--directory-include 'collector*.yaml'` renders only the files that match.
4. **Let prune clean up.** Automated sync with `prune: true` deletes what is no longer rendered:
   ```bash
   argocd app get collector --refresh
   argocd app wait collector --sync --health
   kubectl -n telemetry get pods        # only metrics-collector remains
   ```
   Then run `check` in the game.
