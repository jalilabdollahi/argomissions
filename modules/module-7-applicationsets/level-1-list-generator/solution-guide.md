# Walkthrough — The Missing Region

1. **See who creates the Applications.**
   ```bash
   argocd app list                                    # geo-edge-us-east, geo-edge-ap-south
   kubectl -n argocd get applicationset geo-edge -o yaml
   ```
   The Applications have an `ownerReference` to the ApplicationSet. The spec has one `list` generator with two
   elements: `us-east` and `ap-south`. The status shows no error: the set is healthy, it just has two inputs.
2. **Add the third element.** In `geo-edge-appset.yaml`:
   ```yaml
   generators:
   - list:
       elements:
       - region: us-east
       - region: ap-south
       - region: eu-west
   ```
3. **Apply it.**
   ```bash
   kubectl apply -f geo-edge-appset.yaml
   ```
   (or `kubectl edit applicationset geo-edge -n argocd`).
4. **Watch the new Application appear.** The controller reconciles immediately after the change:
   ```bash
   argocd app list
   argocd app wait geo-edge-eu-west --health
   ```
5. **Verify.**
   ```bash
   kubectl -n geo-eu-west get deploy,svc
   kubectl -n geo-eu-west run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s geo-edge
   ```
   It answers `geo-edge eu-west`. Then run `check` in the game.

Creating `geo-edge-eu-west` with `kubectl apply` of an Application would run, but the ApplicationSet would
not own it: it would be neither managed nor pruned by the set.
