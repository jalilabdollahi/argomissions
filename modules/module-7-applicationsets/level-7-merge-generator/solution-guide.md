# Walkthrough — Overrides Ignored

1. **Compare intent and result.**
   ```bash
   argocd app list                                  # three apps, all Synced / Healthy
   argocd app get parcel-api-prod                   # helm parameters: replicas=1, banner=parcel-api prod
   kubectl -n argocd get applicationset parcel-api -o yaml | grep -B2 -A12 'merge:'
   ```
   The ApplicationSet has no error: the merge generator ran fine, it just produced the base values for prod.
2. **Read the generator.** `mergeKeys: [env]` with a base list whose elements are `env: dev|stage|prod`, and an
   override list with one element `environment: prod, replicas: "3", banner: ...`.
3. **Understand the merge.** The first generator is the base. For every following generator, an element is
   merged into the base element whose `mergeKeys` fields have the same values. The override element has no `env`
   field, so there is nothing to match: it is dropped silently.
4. **Fix the override list** in `parcel-api-appset.yaml`:
   ```yaml
         - list:
             elements:
             - env: prod            # was: environment: prod
               replicas: "3"
               banner: "parcel-api prod priority-lane"
   ```
   and apply it: `kubectl apply -f parcel-api-appset.yaml`.
5. **Watch the generated Application change.**
   ```bash
   argocd app get parcel-api-prod | grep -i -A3 parameters
   kubectl -n parcel-prod get deploy parcel-api
   kubectl -n parcel-prod run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s parcel-api
   ```
   Three replicas, `parcel-api prod priority-lane`. Then run `check` in the game.

Do not edit `parcel-api-prod` itself (`argocd app set`, `kubectl edit app`): the ApplicationSet owns its spec and
writes it back.
