# Mission Control

## What broke
A platform rebuilt from Git came up green at the top and broken underneath, and every layer hid the next:
the root skipped the AppProjects (a subfolder it does not read), so `meridian-core` pointed at a missing project;
the ApplicationSet used old template syntax under `goTemplate: true`, so it generated nothing; once it did, the
edge project did not admit the third district; the core Application had no `CreateNamespace`, and finally its
PostSync smoke test called a port the Service does not have.

## Why Argo CD behaves this way
Each layer is a separate controller loop with its own failure mode. The root only creates what its *path* contains
(non-recursive by default), and it creates everything in one sync unless sync-waves say otherwise, so objects that
depend on each other (project before Application) race on a fresh cluster. The ApplicationSet controller renders
the template for each generator element: the syntax must match `goTemplate`, and a rendering error stops the whole
set. An Application is only admitted if its source and destination are allowed by its AppProject, checked at
comparison time (`InvalidSpecError`) and again at sync time. A sync creates a missing namespace only with
`CreateNamespace=true`. PostSync hooks run after the resources are healthy; a failed one fails the whole sync
even though the workload is fine.

## The fix
Projects in the folder the root reads, in wave -1; `{{.district}}`; `meridian-harbor` in the edge project's
destinations; `CreateNamespace=true` on `meridian-core`; the smoke test on the Service's real port.

## In real life
A full rebuild is the real test of a GitOps platform: whatever was created by hand over the years, in the wrong
order, or because a project once happened to exist, shows up now. The checklist is always the same: what does the
root really contain, in which order does it apply, which controller rejects what, and does every layer work from an
empty cluster. Check the last layer only when the earlier ones are verified; it is a poor use of a night to debug a
smoke test while the project does not exist.

## Commands worth remembering
```bash
argocd app get ROOT ; argocd app manifests ROOT
kubectl -n argocd describe applicationset NAME
kubectl -n argocd get appproject NAME -o yaml
argocd app get APP --show-operation
argocd proj get NAME
```

## Common mistakes
- Applying a corrected ApplicationSet or project with `kubectl`: the root reverts or ignores it, and a rebuild loses it.
- Widening a project to `*` to get one namespace in.
- Treating the green root as "healthy platform".

## Argo CD 2.x vs 3.x
With `goTemplate: true` the `{{district}}` syntax is rejected with `function "district" not defined`; the default
(non-Go) templates use `{{district}}`. In 3.x annotation-based tracking records the owner of each generated
object, which the validator uses to prove that the root and the ApplicationSet own what they should.
