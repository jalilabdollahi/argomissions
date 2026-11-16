# One Secret For The Org

## What broke
Five private repositories, five Applications, zero credentials in Argo CD. Every repo-server fetch was
anonymous and failed with `authentication required`. Fixing it five times (five `argocd repo add`) would work today and
hurt later: five passwords to rotate, and a sixth repository next quarter fails again until someone remembers.

## Why Argo CD behaves this way
Argo CD resolves credentials for a repository URL in two steps: first a **repository** entry for exactly that URL; if there
is none (or it has no login), the longest matching **credential template** (`repo-creds`) whose `url` is a *prefix* of the
repository URL. A template is a Secret labelled `argocd.argoproj.io/secret-type: repo-creds` with `url`, `username`,
`password` (or an SSH key, a GitHub App...). A repository never needs to be registered when a template covers it: new repos
under the prefix just work, and rotating the password is one edit.

## The fix
Add a template for `http://gitea.gitea.svc.cluster.local:3000/platform` (`argocd repocreds add`, the UI, or the Secret), with
the read-only machine user, then refresh the apps.

## In real life
A GitHub organisation or GitLab group usually gets one template (often a GitHub App or a deploy token for the group). Put
the prefix at the organisation level, not the host, so that a token for one team does not unlock another team's repos
mounted on the same host, and keep individual `repository` entries for outliers such as a repo with its own deploy key.

## Commands worth remembering
```bash
argocd repocreds list
argocd repocreds add URL_PREFIX --username U --password P
argocd repo list
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=repo-creds
```

## Common mistakes
- A prefix that names one repository (`.../platform/kiosk-menu`): only that repo is covered.
- Writing the prefix with the laptop's URL (`http://localhost:...`) instead of the one the repo-server uses.
- Adding the template and registering every repository anyway, keeping both rotation points.
