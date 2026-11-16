# The Secret Argo CD Ignores

## What broke
The credentials were correct and they were in the right namespace, but the Secret carried the label
`argocd.argoproj.io/secret-type: repo`. The valid value is `repository`. To Argo CD that Secret does not exist as a
repository, so the repo-server kept reading Git anonymously and got `authentication required`.

## Why Argo CD behaves this way
Argo CD has no "Repository" custom resource. Its settings (repositories, credential templates, clusters, GPG keys) are
ordinary Secrets in the `argocd` namespace, and the **label selector** `argocd.argoproj.io/secret-type` is the only thing
that says what a Secret is: `repository`, `repo-creds`, `cluster`, `repository-write`. The API server and repo-server list
Secrets in their own namespace with that selector. No label, wrong value or another namespace means the Secret is invisible,
and there is no error: nothing logs "ignored secret". That is why `argocd repo list` is the first thing to check.

## The fix
Correct the label value (`repository`), or let `argocd repo add` generate the Secret. The change is picked up without a restart.
Then hard-refresh the Application so the cached error is dropped.

## In real life
Declarative setups (Helm values, kustomize, sealed/external secrets) make this typo easy and hard to see in review:
the manifest looks complete. Add a CI check that lists Secrets by the label, or verify with `argocd repo list` after every
rollout. The same trap exists for cluster Secrets and for a Secret created in the Application's own namespace.

## Commands worth remembering
```bash
argocd repo list
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=repository
kubectl -n argocd get secret NAME --show-labels
kubectl -n argocd label secret NAME argocd.argoproj.io/secret-type=repository --overwrite
```

## Common mistakes
- Creating the repository Secret in the application's namespace instead of `argocd`.
- Making the repo public because "Argo CD is not picking up my secret".
- Using `repo-creds` for a single repository without a URL prefix that matches; it is a template, not a repo entry.
