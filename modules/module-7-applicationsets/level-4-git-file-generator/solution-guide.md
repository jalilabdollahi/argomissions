# Walkthrough — Config Field Typo

1. **Read the status.**
   ```bash
   kubectl -n argocd get applicationset tenant-portals -o jsonpath='{.status.conditions[0].message}'
   ```
   `failed to execute go template {{.namespace}}: ... map has no entry for key "namespace"`. No Applications
   exist: one bad parameter set stops the whole generation.
2. **Find the input that lacks the key.**
   ```bash
   cd tenant-stack
   grep -H -E 'namespace|nameSpace' tenants/*/config.json
   ```
   `tenants/globex/config.json` has `"nameSpace"` while the others have `"namespace"` (JSON keys are case sensitive).
3. **Fix the Git config.**
   ```bash
   sed -i.bak 's/"nameSpace"/"namespace"/' tenants/globex/config.json && rm tenants/globex/config.json.bak
   git add -A && git commit -m "globex: fix namespace key" && git push
   ```
4. **Let the set re-read Git** (it polls every few minutes; this forces it):
   ```bash
   kubectl -n argocd annotate applicationset tenant-portals argocd.argoproj.io/application-set-refresh=true --overwrite
   argocd appset get tenant-portals
   argocd app list                  # tenant-acme, tenant-globex, tenant-initech
   ```
5. **Verify**: `argocd app wait tenant-globex --health`, curl `tenant-portal.tenant-globex` answers
   `portal globex silver`. Run `check` in the game.
