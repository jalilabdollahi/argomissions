# Repo Not Permitted

## What broke
The Application was perfectly valid YAML pointing at a perfectly reachable repository, yet Argo CD refused to
look at it: `application repo ... is not permitted in project 'claims'`. Nothing was wrong in Git or in the
cluster; the **AppProject** did not allow that source.

## Why Argo CD behaves this way
Every Application belongs to exactly one **AppProject**. A project is a fence: `sourceRepos` says which Git or
Helm repositories its Applications may read, `destinations` says where they may deploy, plus cluster-resource
and namespace-resource allow/deny lists. The check happens when the controller validates the Application spec,
before any repo-server call, so you see an `InvalidSpecError` condition and an `Unknown` sync status, not a
sync failure. The patterns are globs matched against the repo URL, which is why `claims-*` covers
`.../claims-api.git` but not `.../intake-gateway.git`.

## The fix
Change the project that sets the policy: add the exact repository (`argocd proj add-source`) or a narrow glob.
The Application stays in its project and, being automated, deploys as soon as the spec is valid again.

## In real life
Platform teams hand each team a project and a naming convention. The classic ticket is "my new repo is not
permitted": somebody named the repo outside the convention. The shortcut of moving the app to `default` (which
allows `*`) or adding `*` to the project removes the fence for everybody. Review `sourceRepos` changes like
firewall rules.

## Commands worth remembering
```bash
argocd proj get claims
argocd proj add-source claims REPO_URL
argocd proj remove-source claims REPO_URL
kubectl -n argocd get appproject claims -o yaml
argocd app get claims-intake --hard-refresh
```

## Common mistakes
- Setting `spec.project: default` on the Application: it works, and the team has silently left its fence.
- Adding `*` to `sourceRepos`: every repository on the Git server can now deploy into this project.
- Typing the laptop URL (`localhost:3300`) into the project: the pattern must match the URL the Application uses.
