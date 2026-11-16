# Frozen Friday

## What broke
The freeze did what it was told. A **deny sync window** with schedule `* * * * *` and a 24 hour duration is
active every minute, so it is always active, for every application it matches. Argo CD refuses syncs: the
automated policy waits silently, and a manual sync fails with `cannot sync: blocked by sync window`. Nobody
had thought about the one case a freeze must allow: the urgent, approved fix.

## Why Argo CD behaves this way
Sync windows live on the **AppProject** (`spec.syncWindows`), not on the Application, so one change can freeze a
whole team. A window has a kind (`allow` or `deny`), a cron `schedule`, a `duration`, and selectors for
applications, namespaces and clusters. Rules: a deny window beats an allow window; when allow windows exist,
syncs are only possible inside them; **`manualSync: true`** lets people (and API calls) start a sync even while
the window denies automated ones. The application controller enforces the windows itself: patching an
`operation` onto the Application by hand stays "blocked by sync window" as well.

## The fix
Enable `manualSync` on the deny window (`argocd proj windows enable-manual-sync billing-core 0`) and run the
sync by hand. The freeze keeps blocking every automated sync; an approved manual one goes through. Narrowing
the window to the real freeze hours is the other valid answer.

## In real life
Freezes are common around month-end, holidays and launches, and the failure mode is always the same: an
emergency during the freeze and a team editing the project at 2 a.m. under pressure. Decide in advance who
may sync manually (RBAC `sync` permission) and encode it with `manualSync`, rather than deleting the window,
which silently re-enables every automated deployment. Remember that windows use UTC unless a `timeZone` is set.

## Commands worth remembering
```bash
argocd proj windows list PROJECT
argocd proj windows add PROJECT --kind deny --schedule '0 17 * * 5' --duration 62h --applications '*' --manual-sync
argocd proj windows enable-manual-sync PROJECT ID
argocd proj windows delete PROJECT ID
argocd app get APP            # shows SyncWindow: Sync Allowed / Sync Denied
```

## Common mistakes
- Deleting the window: the fix goes out, and so does every other pending change.
- Adding an `allow` window next to the deny one: deny wins, nothing changes.
- Hot-patching the Deployment with `kubectl`: the service looks fixed, Argo CD never deployed it, and the app stays OutOfSync.
