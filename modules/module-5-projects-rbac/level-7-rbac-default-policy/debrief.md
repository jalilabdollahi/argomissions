# Everyone Is Admin

## What broke
Nothing looked broken, which is the problem. A line added for a demo, `policy.default: role:admin`, turned every
authenticated user into a full administrator. Argo CD was doing exactly what its configuration said: bob, with
no policy of his own, got the default role, and the default role could delete anything.

## Why Argo CD behaves this way
Authorization is Casbin over `argocd-rbac-cm`. A request is allowed if any policy of the user (or of the roles
and groups bound to the user with `g, subject, role`) allows it. **`policy.default`** is the role every
authenticated user implicitly gets, so it acts as a floor for everybody. Its built-in values are `role:readonly`
(`get` on everything) and `role:admin`; leaving it empty gives local accounts no permissions at all, they
cannot even list applications. The built-in `admin` account is mapped to `role:admin` by Argo CD itself,
which is why changing the default never locks you out.

The key is the subject name: for local accounts it is the account name (`alice`), for SSO users it is the
`sub` claim or a group from the `scopes` claim list.

## The fix
Set `policy.default: role:readonly` and give the people who need more an explicit binding in `policy.csv`
(`g, alice, role:admin`). Verify with `argocd account can-i VERB RESOURCE OBJECT` logged in as each identity.

## In real life
`role:admin` as the default is the classic "temporary" change that is still there two years later; with SSO
it means every employee who can reach the login page administers production. Teams usually keep
`argocd-rbac-cm` in Git, map SSO *groups* instead of individual users, and review the default policy as part
of onboarding. A quiet audit: log in as a user with no groups and run `can-i`.

## Commands worth remembering
```bash
kubectl -n argocd get cm argocd-rbac-cm -o yaml
argocd account list
argocd account can-i sync applications 'my-project/*'
argocd account get-user-info
argocd login HOST --username USER --config /tmp/other-cli     # a second identity, keeps your admin session
```

## Common mistakes
- Setting the default to an empty string: nobody (except admin and explicit bindings) can see anything.
- Lowering the default and forgetting to bind the people who really need admin rights.
- Granting `role:admin` to each account to make the symptom go away instead of fixing the default.

## Argo CD 2.x vs 3.x
Nothing changed for `policy.default` itself. What changed in 3.x is how much `role:admin` and `update`/`delete`
policies cover for sub-resources (see the fine-grained RBAC level), so a default that is too generous is now
worth a second look in both directions.
