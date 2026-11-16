# Works On My Laptop

## What broke
The Application `orders` was created with `http://localhost:3300/platform/orders.git`, the address the developer
types into their own browser and `git clone`. It worked for them, so they assumed it worked for Argo CD. But
Argo CD never saw the repo: every comparison failed with `connection refused` and the Application stayed
`Unknown`, with nothing deployed.

## Why Argo CD behaves this way
Argo CD is split into components that run as pods. Fetching Git is the job of the **repo-server**: the
application controller asks it for the rendered manifests of `repoURL` at `targetRevision`. The URL is
therefore resolved *from inside that pod*, using the cluster's DNS and network. `localhost` means "this pod",
and port 3300 is just a port-forward on the player's machine. The same repo has two addresses depending on who
is asking:

* your laptop: `http://localhost:3300/platform/orders.git`
* inside the cluster: `http://gitea.gitea.svc.cluster.local:3000/platform/orders.git`

Because the repo-server could not list refs, no revision was resolved, so the Application has no sync status at
all (`Unknown`), which is different from `OutOfSync`: Argo CD does not know what Git says.

## The fix
Change `spec.source.repoURL` to the in-cluster URL and sync. Nothing in Git changed: the manifests were fine.

## In real life
The classic version is a developer pasting a URL that only works on the corporate VPN, behind a port-forward,
through a `127.0.0.1` tunnel, or via an SSH alias from their `~/.ssh/config`. Argo CD needs a URL (and
credentials, see the repository-credentials levels) that works from the cluster network. Typos in hostnames and
missing DNS suffixes across namespaces fail the same way, and `kubectl exec` into the repo-server to run
`git ls-remote` is a fast way to test a URL from the right place.

## Commands worth remembering
```bash
argocd app get NAME                 # conditions show the exact error
argocd app set NAME --repo URL      # change the source repo
argocd repo list                    # repositories Argo CD knows credentials for
kubectl -n argocd logs deploy/argocd-repo-server
```

## Common mistakes
- Replacing `localhost` with another name that does not resolve in the cluster (`gitea`, `gitea:3000`): the
  Service lives in namespace `gitea`, so the name must include it (`gitea.gitea.svc.cluster.local`).
- Changing the URL but never syncing: the Application is OutOfSync, nothing is deployed yet.
- Port-forwarding Gitea "for Argo CD": a forward on your laptop is not reachable from the cluster either.
