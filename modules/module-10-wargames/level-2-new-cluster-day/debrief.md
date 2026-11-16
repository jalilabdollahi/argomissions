# First Day On The New Cluster

## What broke
A cluster rebuild exposed four things the old cluster had hidden:
1. **No root Application.** The one object that is applied by hand (`bootstrap/root.yaml`) had never been applied here.
   Nothing in Git can create the Application that reads Git.
2. **No repository credentials.** The repo had become private after the old cluster was built; the new Argo CD had
   no secret for it (`authentication required`), so even the root could not render anything.
3. **`tidewater-ledger` never asked for its namespace.** On the old cluster someone had created `tidewater-ledger`
   by hand years ago, so nobody noticed the Application lacks `CreateNamespace=true`.
4. **Project `tidewater` did not list `tidewater-jobs`.** Another drift that a long-lived project had accumulated
   (the batch Application's destination was never permitted on paper).

## Why Argo CD behaves this way
The app-of-apps pattern needs a seed: the root is the only manifest that is applied outside Git, and its
`automated` policy with `prune` and `selfHeal` makes Git authoritative for every child Application and AppProject.
That is also why hand fixes to children are reverted. Repository access is part of Argo CD's own configuration
(a Secret labelled `argocd.argoproj.io/secret-type: repository` or a `repo-creds` template), not of any Application,
and it is not stored in Git. Destination permissions are checked per Application against its project on every
reconcile: a fresh cluster re-evaluates everything an old cluster had happened to tolerate.

## The fix
Add the credentials (`argocd repo add` with the read-only machine user), apply the root, then commit the two
corrections to Git: `CreateNamespace=true` on the ledger and a `tidewater-jobs` destination in the project. The root
applies them; nothing is patched live.

## In real life
Disaster-recovery drills are where GitOps promises get audited. The usual findings are exactly these: the bootstrap
step lives in somebody's shell history, credentials were configured by hand, namespaces were created manually years ago,
and a project allowed more (or less) than its Applications needed. A rebuild runbook is only real if someone has
run it on an empty cluster. Keep credentials for the repo out of Git (sealed or external secrets), keep the
bootstrap manifest in the repo's README path, and make every namespace come from Git.

## Commands worth remembering
```bash
kubectl apply -f bootstrap/root.yaml
argocd repo add URL --username U --password P      # or a labelled Secret
argocd repo list                                    # CONNECTION STATUS per repository
argocd app get ROOT --hard-refresh
argocd proj get PROJECT                             # destinations, whitelists
kubectl -n argocd get applications,appprojects
```

## Common mistakes
- Making the repository public to "get it working": the security review's requirement is undone.
- Using the `player`/admin account for Argo CD: one leaked Secret then means write access to every repo.
- Creating the missing namespace with `kubectl`: the Application turns green and the next rebuild fails the same way.
- Widening the project to `*` instead of adding the one destination the batch job needs.
- Patching the child Applications live: the root's self-heal reverts them within seconds.

## Argo CD 2.x vs 3.x
The same chain appears on 2.x. On 3.6.1 the child Applications are tracked by annotation
(`argocd.argoproj.io/tracking-id: tidewater-root:argoproj.io/Application:argocd/<name>`), which is how the owner
of each child is read; the root stays Healthy even while a child is broken, and an automated sync with `retry` keeps retrying with the options it started with, so a Git fix needs `argocd app terminate-op` (or a wait of a few minutes) to take effect.
