# Walkthrough — Delete The Set, Lose The Fleet

1. **Look at what holds the fleet together.**
   ```bash
   kubectl -n argocd get applicationset
   kubectl -n argocd get application kiosk-north -o jsonpath='{.metadata.ownerReferences}{"\n"}{.metadata.finalizers}{"\n"}'
   for r in north south east; do kubectl -n kiosk-$r get deploy kiosk-web -o jsonpath='{.metadata.uid}{"\n"}'; done
   ```
   The Application is owned by `kiosk-apps` and has the finalizer `resources-finalizer.argocd.argoproj.io`
   (the ApplicationSet controller adds it to every generated Application by default).
2. **Why the plain delete is dangerous.** Deleting `kiosk-apps` makes Kubernetes garbage-collect its Applications;
   the finalizer then makes Argo CD delete every resource each Application manages. The kiosks go dark until the new
   set recreates everything.
3. **Option A — preserve the resources.** Tell the controller not to cascade, wait until it removed the finalizers,
   then delete and recreate:
   ```bash
   kubectl -n argocd patch applicationset kiosk-apps --type merge \
     -p '{"spec":{"syncPolicy":{"preserveResourcesOnDeletion":true}}}'
   kubectl -n argocd get application kiosk-north -o jsonpath='{.metadata.finalizers}'   # empty now
   kubectl -n argocd delete applicationset kiosk-apps
   kubectl apply -f kiosk-fleet-appset.yaml
   ```
   **Option B — orphan the children:** `kubectl -n argocd delete applicationset kiosk-apps --cascade=orphan`
   keeps the three Applications (no owner any more); applying `kiosk-fleet` adopts them.
4. **Verify.**
   ```bash
   argocd app list                                  # kiosk-* Synced / Healthy
   kubectl -n argocd get applications -o custom-columns=N:.metadata.name,OWNER:.metadata.ownerReferences[0].name
   for r in north south east; do kubectl -n kiosk-$r get deploy kiosk-web -o jsonpath='{.metadata.uid}{"\n"}'; done
   ```
   The UIDs are the ones from step 1. Then run `check` in the game.
