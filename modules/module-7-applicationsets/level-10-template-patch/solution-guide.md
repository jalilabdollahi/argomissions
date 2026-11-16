# Walkthrough — Only Prod Gets Auto-Sync

1. **See the state.**
   ```bash
   argocd app list                              # all three OutOfSync
   argocd app get lumen-prod | grep -i 'sync policy'    # Manual
   kubectl -n argocd get applicationset lumen-gateway -o jsonpath='{.spec.template.spec.syncPolicy}'
   ```
   The template only carries `syncOptions`; nothing is automated anywhere.
2. **Do not touch the children.** `argocd app set lumen-prod --sync-policy automated` works for a moment, then the
   ApplicationSet controller rewrites the Application from the template and the policy is gone.
3. **Add a `templatePatch`** to `lumen-appset.yaml` (spec level, next to `template`):
   ```yaml
     templatePatch: |
       {{- if eq .env "prod" }}
       spec:
         syncPolicy:
           automated:
             prune: true
       {{- end }}
   ```
   Apply it: `kubectl apply -f lumen-appset.yaml`. The patch is rendered for every element and merged over the
   template; for `dev` and `stage` the condition is false and nothing is added.
4. **Verify.**
   ```bash
   argocd app get lumen-prod | grep -i 'sync policy'    # Automated (Prune)
   argocd app list                                      # prod Synced, dev/stage still OutOfSync
   ```
   Run `check` in the game.

Another valid design: two list generators (dev+stage, prod) where the prod one has its own generator-level
`template` adding the sync policy.
