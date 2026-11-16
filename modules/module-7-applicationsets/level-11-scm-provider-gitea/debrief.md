# Every Repo An App

## What broke
The SCM provider generator could not authenticate: its `tokenRef` named the key `access-token`, while the Secret
`gitea-scm-token` stores the token under `token`. The ApplicationSet went into `ErrorOccurred` with
`error fetching Gitea token: key "access-token" in secret argocd/gitea-scm-token not found` and generated nothing.

## Why Argo CD behaves this way
The SCM provider generator is a small controller-side client: on every reconcile (and every `requeueAfterSeconds`,
30 minutes by default) the **applicationset-controller** calls the provider's API (here Gitea at
`gitea.gitea.svc.cluster.local:3000`) to list the repositories of the owner, applies the `filters`
(`repositoryMatch`, `pathsExist`, `branchMatch`, ...) and renders one Application per repository and branch. The
parameters it exposes are `organization`, `repository`, `url`, `branch`, `sha`, `short_sha`, `labels`...

Things worth knowing about this generator on Gitea:

* The token is read from a Secret in the `argocd` namespace through `tokenRef` (`secretName` + `key`); a missing
  Secret or key is reported as an error condition and, as with every generator error, already generated Applications
  are kept, not deleted.
* The token needs the `read:repository`, `read:organization`, `read:user` **and `read:issue`** scopes on Gitea 28:
  without `read:issue` the repository listing is rejected.
* `{{.url}}` is the clone URL as the **API** reports it: with the default `cloneProtocol` that is an `ssh://` URL, and
  even the https one points at Gitea's configured public address (`localhost` on a laptop). Neither is something the
  repo-server can reach, so this ApplicationSet builds the in-cluster URL itself from `{{.organization}}` and
  `{{.repository}}`.
* Filters are your guard rail: without `repositoryMatch` every repo of the organization, `wiki-notes` included,
  becomes an Application (and fails, there is no `deploy/` folder).

## The fix
Make the reference match the Secret: `key: token`, or add an `access-token` key to the Secret. Keep the filter. The
three Applications appear within a few seconds of the ApplicationSet being updated. If you change only the Secret
instead, nothing triggers the controller (Secrets are not watched): it retries the failed generator with a growing
back-off of up to several minutes, unless you force a refresh with the annotation
`argocd.argoproj.io/application-set-refresh=true` on the ApplicationSet.

## In real life
Per-team or per-org "every repo is an app" setups save a lot of YAML, and they fail in boring ways: expired or
under-scoped tokens, a provider rate limit hit by a short `requeueAfterSeconds`, a repo that matches the filter but
has no manifests (use `pathsExist`), or a self-hosted provider with a private CA (`insecure: true` for TLS, not needed
here because the API is plain http). Read the condition first.

## Commands worth remembering
```bash
kubectl -n argocd get applicationset mesh-fleet -o json | jq '.status.conditions'
argocd appset get mesh-fleet
kubectl -n argocd logs deploy/argocd-applicationset-controller | grep -i error
kubectl -n argocd get secret gitea-scm-token -o json | jq '.data | keys'
```

## Common mistakes
- Creating the Applications by hand: they are not owned by the set and the generator stays broken.
- Removing the `repositoryMatch` filter to "see if it works": every repository in the organization becomes an Application.
- Using `{{.url}}` as `repoURL` and ending up with a `localhost` or `ssh://` address the repo-server cannot use.

## Argo CD 2.x vs 3.x
The SCM provider generator is unchanged. Note that `scmProvider` generators can be disabled or restricted with
`applicationsetcontroller.allowed.scm.providers` / `applicationsetcontroller.enable.scm.providers` in
`argocd-cmd-params-cm`; this cluster allows them.
