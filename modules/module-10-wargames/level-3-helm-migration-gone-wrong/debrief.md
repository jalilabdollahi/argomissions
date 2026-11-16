# The Chart Migration

## What broke
Four independent mistakes in one "simple" migration, each hidden by the previous one:
1. **A values file that does not exist.** The Application asked for `values/prod.yaml`; the file is
   `values/production.yaml`. Argo CD reported `ComparisonError` and could not show any diff at all.
2. **Release name drift.** A Helm chart names objects after the release, and the release defaults to the
   Application name (`stockroom-db-v2`). Deployment, Service and the claim would all change name.
3. **The volume that would have been replaced.** The chart's default claim name (`<release>-storage`) differs from
   the existing claim `stockroom-db-data`. A sync would run the database on a new empty volume; a pruning sync
   would delete the old one, together with the inventory data.
4. **A stale Helm parameter.** `message` was pinned on the Application during an old incident. Parameters beat
   values files, so production values silently lost.

## Why Argo CD behaves this way
Argo CD renders the chart with `helm template`, using the release name from `spec.source.helm.releaseName`
(default: the Application name), then compares and applies the result like any other manifests; anything it
tracked before that is no longer rendered becomes a **prune candidate**. A render error stops everything,
including the diff. Value precedence in Helm is: chart `values.yaml` < values files (in order) < `parameters`
(`--set`), and Argo CD does not warn about a parameter that shadows a file. PersistentVolumeClaims are adopted by
name, not by role: a claim with the same name as a rendered one is updated in place, anything else is a new object.

## The fix
Right values file, `releaseName: stockroom-db`, the parameter removed, `persistence.claimName` pointing at the
existing claim (in the production values), then read `argocd app diff` until the PVC shows no create and no prune
and sync manually. Prove the data survived: same claim UID, `/seq` still answers.

## In real life
Plain-manifests-to-Helm migrations are routine, and the usual casualties are persistent things: databases, queues,
anything with a PVC. The safe sequence is always the same: make the render succeed, make the names match, read the
diff for creates/prunes of stateful objects, add `Prune=false` or `Delete=false` to claims you cannot lose, and only
then sync. A post-mortem checklist for chart migrations: diff reviewed by a second person, the volume UID recorded
before and after, and manual sync for stateful apps.

## Commands worth remembering
```bash
argocd app get APP -o yaml | grep -A15 helm:
argocd app diff APP                       # creates, updates, and prunes in one view
argocd app set APP --values FILE --release-name NAME
argocd app unset APP --parameter NAME
helm template NAME chart -f chart/values/production.yaml
kubectl -n NS get pvc -o custom-columns=N:.metadata.name,UID:.metadata.uid
```

## Common mistakes
- Syncing with `--prune` to "clean up" after a rename: the old claim is a prune candidate.
- Fixing the release name but not the claim: everything is green and the database is empty.
- Hunting for the stale parameter in the repo: it lives on the Application object, not in Git.
- Hard-coding object names in the chart instead of `releaseName`: valid, but the claim problem remains.

## Argo CD 2.x vs 3.x
Nothing differs for these mechanisms. Compare M3 L3 (release name) and M2 L4 (protecting a claim): on 3.6.1 a
manual sync without `--prune` only reports the old objects as requiring pruning and leaves them untouched.
