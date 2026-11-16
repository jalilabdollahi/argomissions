# CI Cannot Sync

## What broke
The pipeline authenticated fine but every request ended in `PermissionDenied ... permission denied`. The local
account `ci-bot` existed, and Argo CD's default `policy.default` is empty, so an authenticated user with no policy
line may do nothing.

## Why Argo CD behaves this way
Argo CD separates **authentication** from **authorization**. Local accounts are declared in `argocd-cm`
(`accounts.NAME: apiKey, login`: `login` allows a UI/CLI password, `apiKey` allows tokens; the password hash and tokens
are stored in `argocd-secret`). What an identity may do is decided only by Casbin rules in `argocd-rbac-cm`:
`p, subject, resource, action, object, effect` and `g, subject, role`. For applications the object is
`<project>/<application>`, so `shop/*` is the way to scope a pipeline to one project. Changes to the ConfigMap are
picked up within seconds, no restart. `argocd account can-i ACTION RESOURCE OBJECT` asks the server for the
decision for whoever is logged in, the quickest way to test a policy.

## The fix
Create a role with `get` and `sync` on `applications` for `shop/*` and bind `ci-bot` to it with a `g` line. A
policy line naming `ci-bot` directly works as well; a role is easier to reuse when a second pipeline appears.

## In real life
Pipelines are given the narrowest identity that works: usually a project role with a token or a local account with
a one-project policy, because CI credentials leak more often than human ones. `role:admin`, `*` actions and `*/*`
objects are the shortcuts that turn a leaked token into a cluster takeover (an `*` action includes `delete` and
`update`). Note that `argocd app get` as this bot also needs `projects, get` and fails; `app sync` and `app list` do not.

## Commands worth remembering
```bash
argocd account list
argocd account can-i sync applications 'shop/*'
argocd --config /tmp/ci-bot.config login ...        # act as another user without touching your own session
kubectl -n argocd get cm argocd-rbac-cm -o yaml
kubectl -n argocd edit cm argocd-rbac-cm
```

## Common mistakes
- `g, ci-bot, role:admin`: the pipeline can now delete every application.
- `applications, *, shop/*` or `*/*`: far more than sync, or more than one project.
- Setting `policy.default: role:readonly` hoping it helps: the bot can read everything and still cannot sync.

## Argo CD 2.x vs 3.x
In 3.x `update` and `delete` on an application no longer imply the same on its managed resources (they need
`update/*` and `delete/*`), and `logs` is enforced by default. A plain `get, sync` policy like this one is unaffected.
