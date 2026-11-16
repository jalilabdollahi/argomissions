# Walkthrough — Unknown Kind On First Sync

1. **Read the failure.**
   ```bash
   argocd app get sensor-hub        # Failed: failed to discover server resources for group version sensors.argomissions.io/v1
   kubectl get crd | grep argomissions   # nothing
   argocd app get sensor-crds       # OutOfSync / Missing: never synced
   ```
   The `Probe` instance in `hub/` needs the CRD from `crds/`. Argo CD validates (dry-runs) every resource before
   it applies anything, and the API server does not know the kind yet.
2. **Install the CRD through Argo CD.** Applying it with `kubectl` would work once, but nothing would own the
   CRD (no tracking, no drift detection, no pruning).
   ```bash
   argocd app sync sensor-crds
   argocd app wait sensor-crds --health
   kubectl get crd probes.sensors.argomissions.io
   ```
3. **Sync the instances again.**
   ```bash
   argocd app sync sensor-hub
   argocd app wait sensor-hub --health
   kubectl -n sensors get probes
   ```
4. Run `check` in the game.

For the next fresh cluster you do not want a human to remember the order. Options:
* put both Applications in an app of apps and give the CRD Application a lower `argocd.argoproj.io/sync-wave`
  (the parent waits for the child to be Healthy);
* give the instance Application `SkipDryRunOnMissingResource=true` and an automated sync with `retry`, so it
  keeps trying until the CRD shows up.
(If the CRD and the instances were in one Application, Argo CD would apply the CRD first by itself.)
