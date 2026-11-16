# Runbook: Mission Control

1. **Layer 1 - the root.** `argocd app get meridian-root` is Synced but its resource list has no AppProject.
   `git ls-tree -r HEAD --name-only` shows `bootstrap/projects/*.yaml`: the root reads `bootstrap/` without
   recursion. Move the two project manifests into `bootstrap/` (or make the root recurse), and give both
   `argocd.argoproj.io/sync-wave: "-1"` so a fresh bootstrap creates them before `meridian-core` and the ApplicationSet.
2. **Layer 2 - the ApplicationSet.** `kubectl -n argocd describe applicationset meridian-edge` shows
   `function "district" not defined`: with `goTemplate: true` the generator values are `{{.district}}`.
3. **Layer 3 - projects.** Once the set generates the Applications, `meridian-edge-harbor` reports an `InvalidSpecError`
   saying that its destination is not permitted in project `meridian-edge` (`argocd app get meridian-edge-harbor`). Add namespace `meridian-harbor` to the
   project's destinations (not `*`).
4. **Layer 4 - core.** `meridian-core` now compares, but the sync fails: namespace `meridian-core` not found. Add
   `CreateNamespace=true` to its `syncOptions`.
5. **Layer 5 - hooks.** Next the sync passes and the PostSync Job fails (`curl: (7) Failed to connect ... port 8080`):
   the Service exposes port 80. Fix the URL, keep the test able to fail.
6. Push once, let the root sync, refresh the generated Applications, wait for everything Synced and Healthy.
   Verify `argocd app list`, `kubectl -n meridian-core get job`, `argocd app get meridian-core` (hook Succeeded).
