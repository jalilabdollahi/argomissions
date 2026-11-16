# Runbook: stormwatch drift storm

1. **See the drift.** `argocd app diff stormwatch-root` shows `sw-alerts`: live `targetRevision` is a commit SHA, Git says `main`.
   `argocd app diff sw-ingest` shows the annotation `mesh.argomissions.io/epoch` and the debug text in the Deployment args.
2. **Fault 3 - the mesh annotation.** The controller `mesh-stamper` writes `mesh.argomissions.io/epoch` on `sw-ingest`;
   Git sets it too. Add to `apps/ingest.yaml` an `ignoreDifferences` entry for Deployment with
   `jqPathExpressions: ['.metadata.annotations["mesh.argomissions.io/epoch"]']` (or the pointer
   `/metadata/annotations/mesh.argomissions.io~1epoch`, or `managedFieldsManagers: [mesh-stamper]`). It belongs in Git, because
   the root owns the child Application: a live `argocd app patch` is erased as soon as the root syncs.
3. **Fault 2 - nothing heals.** Add `selfHeal: true` to `apps/ingest.yaml` (the alerts child has it) and make the root
   automated with self-heal: `argocd app set stormwatch-root --sync-policy automated --self-heal`. The in-place debug edit of the Deployment is reverted.
4. **Fault 4 - shared ConfigMap.** Unpinning `sw-alerts` makes it deploy release v1.1, whose folder also contains
   `thresholds`: `SharedResourceWarning`. Keep one definition: put `wind_kmh: "90"` next to `rain_mm: "40"` in
   `workloads/ingest/thresholds.yaml` and `git rm workloads/alerts/thresholds.yaml`.
5. **Fault 1 - the pin.** With the Git changes pushed, sync the root (`argocd app sync stormwatch-root`; with self-heal it also
   happens by itself): the live child goes back to `targetRevision: main`, `sw-alerts` deploys v1.1.
6. Verify: root, `sw-ingest`, `sw-alerts` Synced/Healthy at head; `kubectl -n stormwatch get cm thresholds -o yaml`;
   wait twenty seconds and `argocd app get sw-ingest` is still Synced although the annotation changed.
