# Walkthrough — The Webhook's Signature

1. **Look at the diff, twice.**
   ```bash
   argocd app diff profile-svc
   kubectl -n profiles get deploy profile-svc -o jsonpath='{.metadata.labels}{"\n"}'
   sleep 12
   kubectl -n profiles get deploy profile-svc -o jsonpath='{.metadata.labels}{"\n"}'
   ```
   Only `metadata.labels.cost-center` differs, and its live value changes every ~10 seconds.
2. **Find the writer.**
   `kubectl -n profiles get deploy profile-svc --show-managed-fields -o yaml | grep -B3 -A8 'manager: cost-stamper'`
   shows a second field manager owning that label. It lives in namespace `profiles-finops`.
3. **Do not fight it.** `argocd app sync profile-svc` goes `Synced` and is `OutOfSync` again 10 seconds later.
   Deleting `cost-stamper` removes finance's allocation, which is not this team's decision.
4. **Exclude the field from comparison.**
   ```bash
   argocd app patch profile-svc --type merge --patch '{"spec":{"ignoreDifferences":[
     {"group":"apps","kind":"Deployment","name":"profile-svc","jsonPointers":["/metadata/labels/cost-center"]}]}}'
   ```
   Equivalent forms: `jqPathExpressions: ['.metadata.labels["cost-center"]']`, or
   `managedFieldsManagers: [cost-stamper]` to ignore everything that manager writes.
5. **Verify.** `argocd app get profile-svc` is `Synced`, and still is after the label changes again.
   Then run `check` in the game.
