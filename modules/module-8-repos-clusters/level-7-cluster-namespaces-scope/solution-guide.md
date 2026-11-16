# Walkthrough - Namespace Not Managed

1. **Reproduce.**
   ```bash
   argocd app get parcel-hub-us
   # ComparisonError: Failed to load live state: namespace "parcel-us" for Deployment "parcel-hub" is not managed
   ```
   The twin `parcel-hub-eu` is Healthy on the same cluster, so credentials and TLS are fine.
2. **Read the scope.**
   ```bash
   kubectl -n argocd get secret cluster-regional -o jsonpath='{.data.namespaces}' | base64 -d     # parcel-eu
   argocd cluster list                                                                             # regional (1 namespaces)
   ```
   Argo CD only manages the namespaces listed there. `parcel-us` is missing.
3. **Check why the scope exists.** Remove the field and the cluster turns Failed (`forbidden ... at the cluster scope`):
   the ServiceAccount only has Roles in `parcel-eu` and `parcel-us`. So the scope must stay and grow.
4. **Extend it.**
   ```bash
   kubectl -n argocd patch secret cluster-regional --type merge -p '{"stringData":{"namespaces":"parcel-eu,parcel-us"}}'
   # or: argocd cluster set regional --namespace parcel-eu --namespace parcel-us
   ```
5. **Verify.** `argocd app get parcel-hub-us --refresh` becomes Synced/Healthy (the app is automated); check
   `parcel-hub-eu` is still Healthy and `kubectl get deploy -n parcel-us`.
