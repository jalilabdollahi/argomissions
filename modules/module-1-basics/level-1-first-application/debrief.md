# Hello, GitOps

## What broke
Nothing was broken: nothing existed. The manifests were sitting in Git, but Argo CD does not scan repositories
looking for work. Until an **Application** connects a *source* (repo + revision + path) to a *destination*
(cluster + namespace), Argo CD has nothing to reconcile.

## Why Argo CD behaves this way
An Application is a custom resource in the `argocd` namespace. The **application controller** reads it,
asks the **repo-server** to render the manifests at the target revision, compares the result with the live
objects (the *diff*), and reports two independent things:

* **Sync status** — does the cluster match Git? (`Synced` / `OutOfSync`)
* **Health status** — are the objects working? (`Healthy` / `Progressing` / `Degraded` / `Missing` ...)

A new Application without an automated sync policy only *reports*: it is `OutOfSync` / `Missing` until
someone presses Sync. A sync applies the rendered manifests and records which commit was deployed — that SHA
is what `argocd app get` shows next to *Synced to*.

The repo URL is read by the repo-server, a pod inside the cluster. `localhost` there is the pod itself, so the
URL you clone from on your laptop is not the URL Argo CD can use. Here Gitea is reachable in the cluster as
`gitea.gitea.svc.cluster.local:3000`.

## The fix
Create the Application (CLI, UI or YAML), then sync it. The deployed objects get Argo CD's tracking
annotation `argocd.argoproj.io/tracking-id`, which is how Argo CD knows they belong to `status-page`.

## In real life
Teams rarely click **New App** in production: Applications are themselves YAML in a Git repo (see the
"App of Apps" module) so that the list of what runs where is reviewed like any other change. `kubectl apply`
of the same manifests "works" but leaves objects nobody owns: Argo CD will not notice drift, will not prune
them, and the next engineer has no idea where they came from.

## Commands worth remembering
```bash
argocd app list
argocd app create NAME --repo URL --path DIR --revision BRANCH --dest-server https://kubernetes.default.svc --dest-namespace NS
argocd app get NAME            # sync + health + resources
argocd app diff NAME           # what a sync would change
argocd app sync NAME
argocd app wait NAME --health
```

## Common mistakes
- Using the URL you clone from (`http://localhost:3300/...`) — the repo-server cannot reach your laptop.
- Creating the Application and waiting for it to deploy by itself: without `syncPolicy.automated` it never will.
- `kubectl apply`-ing the manifests: the service runs, but it is not GitOps and Argo CD does not own it.
