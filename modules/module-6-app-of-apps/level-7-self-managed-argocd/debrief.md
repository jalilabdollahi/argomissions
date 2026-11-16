# The Permission That Vanishes

## What broke
Nothing was broken: Argo CD did exactly what it was told. Application `argocd-settings` owns the ConfigMaps
`argocd-cm` and `argocd-rbac-cm`, with `selfHeal: true`. The SRE edited the *live* ConfigMap, the controller saw a
difference from Git and put Git's version back within seconds. The "vanished" permission was a self-heal event.

## Why Argo CD behaves this way
Argo CD can manage any Kubernetes object, including its own configuration (it is "just" a ConfigMap in the
`argocd` namespace). With an automated sync policy and self-heal, the desired state in Git is enforced: a live edit
is drift, and drift is reverted. The configuration is read dynamically (RBAC, `argocd-cm` settings), so a sync
takes effect without restarting any component, except for the keys in `argocd-cmd-params-cm`, which are read at
start-up.

Managing Argo CD with itself has one more consequence: a broken config in Git is applied to the very thing that
would apply the fix. Keep a way back (a revert that works through `kubectl`, a break-glass admin account) and
keep what the cluster itself depends on (URL, admin account, timeouts) in the same files.

## The fix
Change the source of truth: add the role and the group mapping to `config/argocd-rbac-cm.yaml`, push, let the
automated sync apply it (or sync by hand), and verify with `argocd admin settings rbac can`. Switching self-heal
off, or deleting the Application "to get it out of the way", would have kept the edit alive and the repo wrong.

## In real life
Teams that bootstrap Argo CD with Helm or Kustomize and then adopt it as an Application hit this the first time
somebody makes an "urgent" RBAC or `argocd-cm` change. It is also the standard way to review who can do what:
RBAC changes become pull requests with an author, a reviewer and a history.

## Commands worth remembering
```bash
argocd admin settings rbac can <subject> <action> <resource> <project/app> --namespace argocd
argocd admin settings rbac validate --namespace argocd
argocd app diff argocd-settings
kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.metadata.annotations}'
```

## Common mistakes
* Using `kubectl edit` for a setting that an Application with self-heal owns: it works for a few seconds.
* Disabling self-heal (or `automated` altogether) to make the edit stick: the cluster is now different from Git
  and the next sync will remove it anyway.
* Granting too much (`p, payments-oncall, *, *, */*, allow`) because the exact action name was unclear: `sync` on
  `applications` in `default/*` is all the incident needs.

## Argo CD 2.x vs 3.x
Argo CD 3.x enforces fine-grained RBAC: `update` and `delete` on an application no longer imply the same
permission on its sub-resources, and `logs, get` is checked (it is no longer implied by `applications, get`). The
auditor role in this repo therefore lists `logs, get` explicitly.
