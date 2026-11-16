# Walkthrough - Inline Values, Ignored

1. **Check what is rendered.**
   ```bash
   argocd app manifests search-suggest | grep -E "replicas|text"   # replicas: 1, -text=search-suggest dev defaults
   cat search-suggest/chart/values.yaml                            # keys: replicaCount, banner
   ```
2. **Look at the Application.**
   ```bash
   kubectl -n argocd get application search-suggest -o jsonpath='{.spec.source.helm}'
   # {"valuesObject":{"search-suggest":{"banner":"...","replicaCount":3}}}
   ```
   The values sit under a `search-suggest:` key. The chart reads `.Values.replicaCount`, not
   `.Values.search-suggest.replicaCount`, so Helm silently ignores them.
3. **Fix the nesting.** Make `valuesObject` look like a values file:
   ```yaml
   helm:
     valuesObject:
       replicaCount: 3
       banner: "search-suggest prod 4.1"
   ```
   with `kubectl -n argocd edit application search-suggest` (or the UI).
4. **Sync and verify.**
   ```bash
   argocd app sync search-suggest
   argocd app manifests search-suggest | grep -E "replicas|text"
   kubectl -n search get deploy search-suggest        # 3/3
   ```
   Then run `check` in the game.
