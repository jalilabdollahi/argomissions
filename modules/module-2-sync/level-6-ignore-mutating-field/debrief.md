# The Webhook's Signature

## What broke
A controller outside the repo rewrote the `cost-center` label of the live Deployment every few seconds, while Git
declared `cost-center: unassigned`. Argo CD compares the live object with the Git manifest field by field, found
a field that differs, and reported `OutOfSync` permanently. Syncing helped for ten seconds, because the writer
simply came back.

## Why Argo CD behaves this way
The comparison ignores fields that exist only on the live object (that is why defaults, status, and labels added
by others do not make apps `OutOfSync`). It cannot ignore a field that Git *does* declare. For those you list the
exceptions on the Application with `spec.ignoreDifferences`, selecting the resource (`group`, `kind`, `name`,
`namespace`) and the field in one of three ways:

* `jsonPointers`: simple and exact (`/metadata/labels/cost-center`);
* `jqPathExpressions`: for lists and patterns (`.spec.template.spec.containers[].resources`);
* `managedFieldsManagers`: "everything this field manager wrote", the most robust against a controller that
  writes many fields; it relies on Kubernetes' `managedFields`, so the controller must use its own field manager.

Alternatively, stop declaring the field in Git; the controller then owns it outright and the Application is
`Synced`. The difference between the two: `ignoreDifferences` documents the conflict in the Application.

## The fix
Add an `ignoreDifferences` entry for the label (or the manager). Do not remove the other team's controller, and do
not copy its value into Git: it changes every few seconds.

## In real life
Typical culprits: mutating webhooks injecting sidecars or annotations, service meshes, cert-manager rewriting
`caBundle` in webhooks and CRDs, operators defaulting spec fields, cloud controllers writing Service annotations.
`ignoreDifferences` can also be set globally in `argocd-cm` (`resource.customizations.ignoreDifferences.<group_kind>`)
when every Application needs the same exception.

## Commands worth remembering
```bash
argocd app diff NAME
kubectl get RESOURCE NAME --show-managed-fields -o yaml     # who owns which field
argocd app patch NAME --type merge --patch '{"spec":{"ignoreDifferences":[...]}}'
```

## Common mistakes
- Syncing repeatedly and reading `Synced` for a few seconds as a fix.
- Deleting the mutating controller (breaks another team) or its webhook (breaks the cluster's policy).
- Ignoring a whole object (`jsonPointers: [/metadata]`) when one field was the problem: real drift then goes unseen.
