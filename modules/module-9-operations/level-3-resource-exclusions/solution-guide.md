# Walkthrough — The Invisible Kind

1. **See what Argo CD sees.**
   ```bash
   argocd app get lexicon-site        # condition ExcludedResourceWarning: Resource /ConfigMap lexicon-pages is excluded in the settings
   argocd app manifests lexicon-site  # (the ConfigMap is rendered from Git ...)
   kubectl -n lexicon get cm          # ... but it does not exist; the pod is stuck in ContainerCreating
   ```
   The application is Synced because Argo CD does not look at excluded kinds at all: it cannot be OutOfSync
   about something it ignores. That is why nothing "failed".
2. **Find the rule.**
   ```bash
   kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.resource\.exclusions}'
   ```
   The first rule excludes `kinds: ["ConfigMap"]` in `apiGroups: ["*"]` for every cluster.
3. **Fix the rule, not the symptom.** Remove the ConfigMap rule and keep the rest (Endpoints, EndpointSlice,
   Lease are the genuinely noisy ones):
   ```bash
   kubectl -n argocd edit configmap argocd-cm        # delete the first list item of resource.exclusions
   ```
   The controller reloads argocd-cm live; no restart.
4. **Let Argo CD create the ConfigMap.**
   ```bash
   argocd app get lexicon-site --refresh     # ConfigMap lexicon-pages: OutOfSync / Missing, warning gone
   argocd app sync lexicon-site
   argocd app wait lexicon-site --health
   ```
   The pod's volume mount succeeds on the next kubelet retry and the Service answers `lexicon-site v3.1`.
