# Walkthrough — Forensics With The CLI

1. **Confirm the symptom.**
   ```bash
   argocd app get rates-service         # Synced, Healthy: Argo CD is doing what Git says
   kubectl -n fx-rates run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s rates-service
   # fx-rates v1.2 currency=USD source=ecb
   ```
   So Git itself contains the wrong value; this is not drift.
2. **List what Argo CD deployed.**
   ```bash
   argocd app history rates-service
   ```
   Five deployments, each with the commit it came from.
3. **Compare revisions without checking anything out.**
   ```bash
   argocd app manifests rates-service --revision <sha-of-entry-1> | grep -A1 BASE_CURRENCY
   argocd app manifests rates-service --revision <sha-of-entry-2> | grep -A1 BASE_CURRENCY
   argocd app manifests rates-service --revision <sha-of-entry-3> | grep -A1 BASE_CURRENCY
   ```
   Entries 1 and 2 render `EUR`, entry 3 renders `USD`: the culprit is the commit of history entry 3
   ("Align environment values with the staging config"). `argocd app diff rates-service --revision <sha>` shows
   the same thing as a diff against the live state.
4. **Read that commit.**
   ```bash
   cd rates-service && git pull && git show <sha-of-entry-3>
   ```
   It flipped `BASE_CURRENCY` to `USD` (and set `LOG_LEVEL` to `debug`).
5. **Fix forward.** Entries 4 and 5 (v1.2, two replicas, TTL 600) are good, so do not reset or roll back to
   entry 2. Either edit the value back:
   ```bash
   sed -i.bak '/name: BASE_CURRENCY/{n;s/"USD"/"EUR"/;}' deploy/deployment.yaml && rm deploy/deployment.yaml.bak
   git commit -am "Restore BASE_CURRENCY=EUR" && git push
   ```
   or `git revert <sha-of-entry-3-commit>` and push.
6. **Verify.** Automated sync deploys the new head; `argocd app history` has a sixth entry and the service
   answers `fx-rates v1.2 currency=EUR source=ecb`. Run `check`.
