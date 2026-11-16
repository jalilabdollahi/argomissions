# ArgoMissions Curriculum

106 levels, 10 modules. Each entry is the contract for one level: **what is broken**, **what the player must
achieve**, **what the validator must prove**, and the most tempting wrong fix it must reject. Authors may refine
names, wording and numbers but must keep the core bug and lesson, and must not drift into another level's lesson.
App / repo / namespace names are suggestions — keep them unique across the whole game.
All levels follow [LEVEL_SPEC.md](LEVEL_SPEC.md). Format: `L<n> slug — Title (XP · difficulty · time)`.

**Premise rule:** every premise below is written for Argo CD 3.6.1 but some are from memory. Verify each one on
the real cluster before building (create the broken state by hand, read the real error). If Argo CD behaves
differently, keep the lesson, change the mechanism, and say so in the debrief.

---

## Module 1 — Argo CD Basics (beginner)

**L1 first-application — Hello, GitOps (100 · beginner · 10m)** ✅ *reference level*
No Application exists for repo `status-page`. Player creates Application `status-page` (deploy/ → ns `status`)
and syncs. Validate: source/destination, Synced+Healthy at head, objects carry Argo's tracking annotation,
Service answers. Reject: `kubectl apply` of the manifests; wrong destination namespace.

**L2 repo-url-localhost — Works On My Laptop (100 · beginner · 10m)**
Application `orders` was created with the URL the developer clones from, `http://localhost:3300/platform/orders.git`
→ ComparisonError, "connection refused" from the repo-server. Player switches `repoURL` to the in-cluster URL
and syncs. Validate: repoURL is the in-cluster URL, Synced+Healthy at head, answers `orders v1.4`.
Reject: a different wrong host (e.g. `http://gitea:3000/...`, which does not resolve from `argocd`).

**L3 wrong-path — The Moved Manifests (100 · beginner · 10m)**
Repo `catalog` history: commit 1 manifests in `k8s/`, commit 2 "restructure: move manifests to deploy/catalog".
Application `catalog` still has `path: k8s` → "app path does not exist". Player fixes the path and syncs.
Validate: path `deploy/catalog`, Synced+Healthy at head, repo head still has no `k8s/`.
Reject: reverting the restructure commit / copying the files back to `k8s/`.

**L4 target-revision-branch — Master Of Nothing (100 · beginner · 10m)**
Repo `invoices` only has branch `main` (the team renamed master). Application `invoices` has
`targetRevision: master` → "unable to resolve 'master' to a commit SHA". Player points it at `main`.
Validate: targetRevision `main` or `HEAD`, Synced+Healthy at main's head, no `master` branch in the repo.
Reject: pushing a new `master` branch.

**L5 create-namespace — No Room At The Inn (100 · beginner · 10m)**
Application `ledger` → namespace `ledger`, which does not exist; the last sync failed with
`namespaces "ledger" not found`. Objective: the Application can deploy to a fresh cluster on its own.
Player adds sync option `CreateNamespace=true` and syncs. Validate: option present in
`spec.syncPolicy.syncOptions`, Synced+Healthy at head, namespace exists.
Reject: `kubectl create namespace ledger` + sync (works today, option missing).

**L6 wrong-cluster — Cluster Not Found (100 · beginner · 10m)**
Application `telemetry` has `destination.server: https://kubernetes.default.svc.cluster.local` (not a
registered cluster) → InvalidSpecError mentioning the cluster. Player discovers registered clusters
(`argocd cluster list`) and uses `https://kubernetes.default.svc` or `name: in-cluster`.
Validate: destination resolves to the in-cluster server, Synced+Healthy at head.
Reject: `destination.name: kubernetes` (another unregistered name).

**L7 manual-sync-pending — The Commit Nobody Shipped (150 · beginner · 10m)**
Repo `search-api` gets commit "release v2.3" after the app was synced at v2.2 (manual policy). The release
manager thinks it is live; the service answers v2.2 and the app is OutOfSync. Player reviews `argocd app diff`
and syncs. Validate: synced at head, answers `search-api v2.3`. Reject: `kubectl patch`/`set` of the live
Deployment args to v2.3 (app stays OutOfSync / not at head).

**L8 synced-but-degraded — Synced But Sick (150 · beginner · 15m)**
Repo `notifier` has an image tag typo (`hashicorp/http-echo:1.O`), `progressDeadlineSeconds: 30` so health
turns Degraded quickly. App is Synced + Degraded. Lesson: sync status ≠ health. Player fixes the tag in Git,
pushes, syncs. Validate: Git has a valid tag, synced at head, Healthy, answers. Reject: `kubectl set image`
(OutOfSync; Git still wrong).

**L9 removed-api — Sync Failed: Unknown Kind (150 · intermediate · 15m)**
Repo `billing` contains a `policy/v1beta1` PodDisruptionBudget (removed in Kubernetes 1.25). Sync fails
(the API server does not know the version). Player changes it to `policy/v1` in Git and syncs.
Validate: PDB `billing` exists (policy/v1), synced at head, Healthy. Reject: deleting the PDB file from Git
(objective says the PDB must exist).

**L10 hotfix-drift — The Hotfix That Must Survive (150 · intermediate · 15m)**
On-call scaled Deployment `checkout` from 1 to 3 replicas with kubectl during a load spike; the app is OutOfSync
and the next sync would scale back to 1. Objective: 3 replicas stay, and Git is the source of truth again.
Player commits replicas 3, pushes, syncs. Validate: Git manifest says 3, 3 ready, synced at head.
Reject: plain sync (reverts to 1); leaving the drift (OutOfSync).

**L11 prune-orphans — The Ghost Worker (150 · intermediate · 10m)**
Commit "retire legacy worker" removed `legacy-worker` Deployment from repo `media`; the app was synced
without pruning, the worker still runs and the app shows OutOfSync / "requires pruning". Player syncs with
prune. Validate: `legacy-worker` gone, other objects untouched (same UIDs), synced at head.
Accept (alt): `kubectl delete` of the worker then refresh. Reject: sync without prune.

**L12 rollback-then-revert — Undo Without Rewriting History (200 · intermediate · 20m)**
Commit "tune worker flags" in repo `reports` breaks the container args (CrashLoopBackOff); it was synced and the
app is Degraded. Objective: previous behaviour live, app Synced at the head of `main`, the bad commit still in
history (no force push) and its change undone at head. Player: `git revert` + push + sync (optionally
`argocd app rollback` first to stop the bleeding). Reject: `argocd app rollback` alone (OutOfSync, not at head);
`git reset --hard HEAD~1 && git push --force` (history rewritten).

---

## Module 2 — Sync Policies & Drift (beginner → intermediate)

**L1 enable-auto-sync — Deploy On Merge (100 · beginner · 10m)** App `metrics-gw` is manual; three commits are
waiting. Team policy: every push to main deploys itself. Validate: `syncPolicy.automated` set, synced at head.
Reject: one manual sync (still manual).

**L2 self-heal — The Drift That Stays (150 · beginner · 10m)** Auto-sync is on but someone keeps editing the
live ConfigMap/replicas; Argo CD shows OutOfSync and leaves it. Enable `selfHeal`. Validate: selfHeal true,
live state equals Git (Synced at head). Reject: manual sync only.

**L3 auto-prune — Automated, But Not Tidy (150 · beginner · 10m)** Automated sync without `prune`; a Service
removed from Git keeps running and the app stays OutOfSync. Enable `automated.prune`. Validate: prune true,
orphan gone, Synced. Reject: deleting the orphan by hand (prune still off).

**L4 prune-false-resource — Keep The Data (200 · intermediate · 20m)** App with auto-prune; the team will move
PVC `uploads` to a separate storage app, and its manifest must leave this repo — but the PVC (and its data,
check UID) must survive. Lesson: per-resource `argocd.argoproj.io/sync-options: Prune=false` (and what the app
status shows afterwards — verify whether it stays OutOfSync and adapt the objective). Reject: just deleting the
file (PVC pruned, UID changes).

**L5 ignore-hpa-replicas — Fighting The Autoscaler (200 · intermediate · 15m)** An HPA scales Deployment `api`
while Git pins `replicas: 2` with self-heal → endless flapping. Fix with `ignoreDifferences` on `/spec/replicas`
(plus `RespectIgnoreDifferences=true`) or by removing `replicas` from Git. Validate: no flapping (replica count
equals HPA's desired count, app Synced). Reject: disabling self-heal.

**L6 ignore-mutating-field — The Webhook's Signature (200 · intermediate · 15m)** A controller/admission
(simulate with a CronJob or a sidecar that annotates/labels the live object) keeps writing a field → permanent
OutOfSync. Use `ignoreDifferences` with `jqPathExpressions`/`managedFieldsManagers`. Validate: Synced while the
mutation continues. Reject: deleting the mutator.

**L7 immutable-field — Field Is Immutable (200 · intermediate · 15m)** Git changes a Deployment's
`spec.selector` (or a Job's template) → sync fails "field is immutable". Player uses `Replace=true` on that
resource (or deletes and re-syncs). Validate: new selector live, Synced at head, Healthy.

**L8 server-side-apply — Annotation Too Long (200 · intermediate · 15m)** A large ConfigMap (> 262144 bytes)
fails client-side apply: `metadata.annotations: Too long`. Enable `ServerSideApply=true`. Validate: ConfigMap
present with expected content, Synced. Reject: shrinking the ConfigMap (objective requires full data).

**L9 allow-empty — Nothing Left To Deploy (150 · intermediate · 10m)** All workloads moved out of repo path; the
automated app refuses ("auto-sync will wipe out all resources") and old objects keep running. Set `allowEmpty`
(or sync manually with prune). Validate: namespace empty of the old objects, app Synced at head.

**L10 sync-retry — Flaky First Contact (200 · intermediate · 15m)** Auto-sync fails because a CRD's CR is applied
before its CRD is established / a dependency appears seconds later; without retry the app stays failed until
the next commit. Configure `syncPolicy.retry` with backoff. Validate: retry set, app Synced+Healthy.

**L11 shared-resource — Two Owners, One ConfigMap (200 · intermediate · 15m)** Apps `web-a` and `web-b` both
manage ConfigMap `feature-flags` in the same namespace → SharedResourceWarning and endless flip of its tracking
annotation/content. Move ownership to one app in Git. Validate: only one app manages it, both Synced.
Reject: `FailOnSharedResource` alone.

**L12 apply-out-of-sync-only — The Slow Sync (150 · intermediate · 10m)** An app with many objects re-applies
all of them every sync, touching objects other controllers own. Use `ApplyOutOfSyncOnly=true`. Validate option
set and Synced (and, if measurable, an untouched object's resourceVersion unchanged across a sync).

---

## Module 3 — Helm, Kustomize & Sources (intermediate)

**L1 helm-values-file — Values Not Found (150 · beginner · 10m)** Helm chart in Git, app references
`valueFiles: [values-prod.yaml]` but the file is `values-production.yaml` → "no such file or directory".

**L2 helm-parameters-override — The Parameter That Wins (150 · intermediate · 15m)** Someone set
`helm.parameters` in the Application (`image.tag=1.0-hotfix`) — Git values changes have no effect. Remove the
override so Git values win. Reject: changing values.yaml again.

**L3 helm-release-name — The Renamed Release (200 · intermediate · 15m)** App switched source from plain manifests
to a chart; chart names objects `{{ .Release.Name }}-api`, the release name defaults to the app name → duplicate
objects / Service selects nothing. Use `helm.releaseName` to keep names stable. Validate expected object names.

**L4 helm-values-object — Inline Values (150 · intermediate · 10m)** Team wants env-specific values in the
Application (`valuesObject`), but YAML put them under `values:` as a non-string / wrong nesting so they are
ignored. Validate rendered replicas/text.

**L5 kustomize-overlay-path — The Base Is Not An Environment (150 · beginner · 10m)** App points at
`kustomize/base` instead of `kustomize/overlays/prod` → wrong replicas / missing patches.

**L6 kustomize-images — Promote Without Editing YAML (200 · intermediate · 15m)** Promote a new image tag
using the Application's `kustomize.images` override (`argocd app set --kustomize-image`), or in the overlay —
validator accepts both but rejects `kubectl set image`.

**L7 kustomize-common-labels — Selector Is Immutable (200 · intermediate · 15m)** A commit added
`commonLabels` (labels: in selectors too) → sync fails on Deployment selector. Use `labels:` with
`includeSelectors: false`.

**L8 directory-recurse — Half The Manifests (150 · beginner · 10m)** Manifests split into `deploy/web/` and
`deploy/db/`; app path `deploy` without `directory.recurse` → only top-level files (none) deployed / Missing.

**L9 directory-exclude — Test Fixtures In Production (150 · intermediate · 10m)** `deploy/` contains
`tests/fixture-*.yaml` that create junk pods; use `directory.exclude` (or `include`).

**L10 multi-source-values — Values From Another Repo (250 · advanced · 20m)** Chart in repo `charts`, values
in repo `env-config`; app uses `sources` with `ref: values` and `$values/...` — the ref name or path is wrong.

**L11 helm-dependency — Missing Subchart (200 · intermediate · 15m)** Chart in Git has a local file dependency
(`file://../common`) whose path is wrong → template error; or `Chart.lock` mismatch. Fix in Git.

**L12 plain-yaml-vs-helm — Detected As The Wrong Tool (200 · intermediate · 15m)** A directory with a
`Chart.yaml` left over (or `kustomization.yaml`) makes Argo CD pick the wrong tool; fix by removing the stray
file or setting the source type explicitly.

---

## Module 4 — Sync Waves & Hooks (intermediate → advanced)

**L1 presync-migration — Migrate Before You Deploy (200 · intermediate · 15m)** A migration Job must finish
before the new Deployment rolls out; it is a plain resource and races the app. Make it a `PreSync` hook.

**L2 sync-wave-order — Config Before Code (150 · intermediate · 10m)** Deployment starts before the ConfigMap it
needs (`CreateContainerConfigError` on first sync); use `argocd.argoproj.io/sync-wave` (ConfigMap -1).

**L3 crd-before-cr — Unknown Kind On First Sync (200 · intermediate · 15m)** CRD and CR in the same app; dry run
fails "could not find the requested resource". Waves and/or `SkipDryRunOnMissingResource=true`. CRD group
`*.argomissions.io`, labelled for cleanup.

**L4 hook-delete-policy — Job Already Exists (200 · intermediate · 15m)** PreSync Job without a delete policy:
second sync fails (Job already exists / immutable). Add `hook-delete-policy: BeforeHookCreation`.

**L5 postsync-smoke-test — The Test That Fails The Sync (200 · intermediate · 15m)** PostSync smoke-test Job
curls the wrong Service port → operation Failed although the app is fine. Fix the test in Git.

**L6 hook-typo — The Hook That Never Ran (150 · intermediate · 10m)** `argocd.argoproj.io/hook: PreSynk` →
treated as a normal resource / ignored; fix annotation.

**L7 wave-blocked-unhealthy — Stuck In Wave 1 (200 · advanced · 15m)** Wave 0 Deployment never becomes
healthy (bad readiness probe), later waves never apply. Fix the probe in Git.

**L8 syncfail-hook — Clean Up On Failure (250 · advanced · 20m)** Team wants a `SyncFail` hook that removes the
maintenance flag (ConfigMap) when a sync fails; the hook exists but in the wrong phase/annotation.

**L9 prune-last — Remove The Old Last (200 · advanced · 15m)** Renaming a Service: old one pruned before the
new one is ready → outage window. Use `PruneLast=true`. Validate option + Synced.

**L10 hook-rbac — Migration Job Forbidden (250 · advanced · 20m)** PreSync Job uses a ServiceAccount whose Role
lacks permission, and the Role is in a later wave than the hook → hook fails. Put RBAC objects in an earlier
wave / as PreSync with lower wave.

---

## Module 5 — Projects & RBAC (intermediate → advanced)

**L1 project-source-repos — Repo Not Permitted (150 · intermediate · 10m)** AppProject `payments` has
`sourceRepos` listing only `payments-*` repos; app uses repo `pay-gateway` → "application repo ... is not
permitted in project". Fix the project (add the exact repo), not by moving the app to `default`.

**L2 project-destinations — Destination Not Permitted (150 · intermediate · 10m)** Project allows namespace
`pay-*`, app targets `payments` → not permitted. Fix allowed destinations. Reject: project `default`.

**L3 cluster-resource-whitelist — ClusterRole Forbidden (200 · intermediate · 15m)** Project has empty
`clusterResourceWhitelist`; the app's ClusterRole is denied. Allow exactly `rbac.authorization.k8s.io/ClusterRole`
(and binding). Reject: `*/*`.

**L4 namespace-resource-blacklist — Secrets Are Blocked (150 · intermediate · 10m)** Project blacklists `Secret`;
the app needs one → sync denied. Lesson: understand the blacklist; correct fix per story.

**L5 local-account-rbac — CI Cannot Sync (250 · advanced · 20m)** Local account `ci-bot` (apiKey) exists in
`argocd-cm` but `argocd-rbac-cm` gives it nothing → "permission denied" when CI syncs. Write a policy that
allows `sync`/`get` on `applications` in project `shop` only. Validate with `argocd account can-i` as the bot.

**L6 project-role-token — A Token For The Pipeline (250 · advanced · 20m)** Create a project role `deployer`
with policy `applications, sync, shop/*, allow` and a JWT token; validator uses the token (stored where the
mission says) to `can-i`. Reject: using the admin password.

**L7 rbac-default-policy — Everyone Is Admin (200 · intermediate · 15m)** `policy.default: role:admin` was set
"for testing". Lock it to `role:readonly` while keeping user `alice` admin via `g, alice, role:admin`.

**L8 fine-grained-update — Update Is Not Delete (250 · advanced · 20m)** Argo CD 3.x: a role with
`applications, update` can no longer update/delete managed resources (`applications, update/*`...). A team role
can patch the app but cannot run the "restart" action / delete a pod. Add the fine-grained permission.
Verify the exact 3.x semantics first.

**L9 sync-windows — Frozen Friday (200 · intermediate · 15m)** A deny sync window (`* * * * *`, duration 24h)
blocks every sync incl. an urgent fix. Add a narrower window / `manualSync: true` per story.

**L10 orphaned-resources — Who Owns This? (200 · intermediate · 15m)** Enable project `orphanedResources`
warnings and remove the orphan the warning exposes (with an ignore rule for a known exception).

---

## Module 6 — App of Apps (advanced)

**L1 root-app-path — The Empty Root (150 · intermediate · 10m)** Root app `platform-root` points at `apps/`
but the child Application YAMLs live in `argocd/apps/` → root Synced with zero children.

**L2 child-namespace — Children In The Wrong Namespace (200 · intermediate · 15m)** Root's destination
namespace is `platform`, so child Application objects are created in `platform` where the controller ignores
them. Fix root destination to `argocd`.

**L3 child-project-missing — Orphaned Children (200 · intermediate · 15m)** Child apps reference project `team-a`
that is not created by the root (or created later) → InvalidSpecError. Add the AppProject to the root repo
(with a lower sync wave).

**L4 cascade-finalizer — Deleting The Child Left Everything (200 · intermediate · 15m)** Child app removed from
Git with root prune → app deleted but its workloads keep running (no `resources-finalizer`). Add the finalizer
and clean up correctly.

**L5 root-delete-danger — The Day The Root Was Deleted (250 · advanced · 20m)** Root with finalizers + prune; an
accidental commit deletes a child → whole service gone. Restore from Git history and protect children with
`Prune=false` / `Delete=false` sync option on child Applications.

**L6 app-health-waves — Waves That Do Not Wait (300 · advanced · 25m)** Children ordered with sync-waves but
Argo CD does not assess Application health by default (since 1.8), so wave 2 starts before wave 1 is healthy.
Add the `argoproj.io/Application` health customization to `argocd-cm`.

**L7 self-managed-argocd — Argo CD Manages Its Own Config (250 · advanced · 20m)** An app manages
`argocd-cm`/`argocd-rbac-cm` from Git; a manual edit in the cluster keeps disappearing. Make the change in Git.

**L8 env-promotion — Staging Before Prod (200 · intermediate · 15m)** Root per environment (`envs/staging`,
`envs/prod`) with child apps tracking different revisions; prod child accidentally tracks `main` instead of tag
`v1.2.0`. Pin prod.

**L9 child-drift-root — Hand-Edited Child App (200 · intermediate · 15m)** Someone `argocd app set` a child's
targetRevision; root self-heal reverts it. Lesson: change it in the root repo.

**L10 bootstrap-from-scratch — Rebuild The Platform (300 · advanced · 25m)** Fresh cluster: player writes the
root Application for an existing GitOps repo (projects + apps, waves) and brings everything up Healthy.

---

## Module 7 — ApplicationSets (advanced)

**L1 list-generator — The Missing Region (150 · intermediate · 10m)** List generator elements lack `eu-west`;
add it. Validate three generated apps Healthy.

**L2 goTemplate-syntax — Template Mismatch (200 · intermediate · 15m)** `goTemplate: true` but templates use
fasttemplate `{{path.basename}}` → literal names / error. Use `{{.path.basename}}`.

**L3 git-directory-generator — Too Many Apps (200 · intermediate · 15m)** Directory generator `apps/*` also
picks `apps/_shared`; add `exclude: true` entry.

**L4 git-file-generator — Config Field Typo (200 · intermediate · 15m)** `config.json` files use `nameSpace`
while the template expects `namespace` → error with `missingkey=error`.

**L5 cluster-generator — Label Me In (250 · advanced · 20m)** Cluster generator selects `env: staging`; the
cluster secret (an alias of in-cluster) lacks the label → zero apps.

**L6 matrix-generator — Every Service In Every Env (250 · advanced · 20m)** Matrix of git directories × list of
envs produces wrong names/collisions; fix the template.

**L7 merge-generator — Overrides Ignored (250 · advanced · 20m)** Merge generator keys mismatch (`mergeKeys`),
so per-env overrides are not applied.

**L8 appset-delete-safety — Delete The Set, Lose The Fleet (250 · advanced · 20m)** Team must recreate an
ApplicationSet; deleting it would delete all child apps and their workloads. Use `preserveResourcesOnDeletion`
/ `applicationsSync: create-update` / non-cascade delete. Validate workloads never went away (UIDs).

**L9 ignore-application-differences — The Set Reverts My Change (200 · intermediate · 15m)** Manual
targetRevision change on a generated app keeps reverting; configure `ignoreApplicationDifferences` (story says
why it is wanted) — or make the change in the template.

**L10 template-patch — Only Prod Gets Auto-Sync (250 · advanced · 20m)** Use `templatePatch` so only
`env=prod` elements get automated sync.

**L11 scm-provider-gitea — Every Repo An App (300 · advanced · 25m)** SCM provider generator for Gitea
(api `http://gitea.gitea.svc.cluster.local:3000`, token secret) with a filter on repo names; token secret key
wrong. Verify Gitea support on 3.6.1.

**L12 pull-request-generator — Preview Environments (300 · expert · 25m)** PR generator for Gitea creates a
preview app per open PR with a label; generator misconfigured (wrong label / owner). Validate an app for the open
PR and none for the closed one.

---

## Module 8 — Repositories, Clusters & Secrets (advanced)

**L1 private-repo-credentials — Authentication Required (150 · intermediate · 10m)** Repo `vault-ui` is
private; app fails "authentication required". Add a repository secret (or `argocd repo add`) with a Gitea user
token or password. Reject: making the repo public.

**L2 repo-secret-label — The Secret Argo CD Ignores (200 · intermediate · 15m)** Repository secret exists but
label is `argocd.argoproj.io/secret-type: repo` (typo) or in another namespace → ignored.

**L3 repo-creds-template — One Secret For The Org (200 · intermediate · 15m)** Five private repos; use a
`repo-creds` credential template for the org URL prefix. Validate apps use the template (no per-repo secrets).

**L4 ssh-repo-known-hosts — Host Key Verification Failed (250 · advanced · 20m)** App uses
`ssh://git@gitea-ssh.gitea.svc.cluster.local:22/platform/x.git` with a deploy key; known_hosts missing → fix
with `argocd cert add-ssh` / `argocd-ssh-known-hosts-cm`. (Expose Gitea SSH in-cluster Service as needed by
the level; never use insecure ignore-host-key.)

**L5 wrong-token — Expired Credentials (150 · intermediate · 10m)** Repository secret holds a revoked Gitea
token → 401. Rotate it.

**L6 cluster-secret-alias — Register A Second Destination (250 · advanced · 20m)** Register cluster `staging`
(same API server via its in-cluster address, bearer token of a ServiceAccount with limited namespaces) through
a cluster secret; app targets `name: staging`. Fix the broken secret (bad CA/server/token key).

**L7 cluster-namespaces-scope — Namespace Not Managed (200 · advanced · 15m)** Cluster secret limits
`namespaces: shop-a`; app deploys to `shop-b` → error. Fix scope or app per story.

**L8 gitea-webhook — Waiting Three Minutes (200 · intermediate · 15m)** Configure a Gitea webhook to
`http://argocd-server.argocd.svc/api/webhook` with a secret matching `webhook.gitea.secret` in `argocd-secret`;
the given webhook has the wrong secret → ignored. Validate a push gets picked up quickly (validator may push a
no-op commit to a scratch branch? no — check config + delivery status via Gitea API).

**L9 gpg-signature — Unsigned Commit Rejected (300 · expert · 25m)** Project requires `signatureKeys`; latest
commit unsigned → sync refused. Sign (gpg on host) or revert per story. Verify gpg availability; skip gpg if
not installed (mark requires).

**L10 secret-in-git — The Leaked Password (250 · advanced · 20m)** A Secret with a real password is committed
plain. Move it out of Git (create it in-cluster out of band, keep the app Synced with the Secret excluded /
managed elsewhere) and rewrite nothing (history kept; rotate the password). Validate app Synced, Secret
present, password rotated, no plaintext at head.

---

## Module 9 — Customization & Operations (advanced → expert)

**L1 custom-health-lua — Forever Progressing (250 · advanced · 20m)** A CR (`Backup.argomissions.io`) has
`status.phase: Done` but Argo CD shows health Unknown/Progressing; add a Lua health check in `argocd-cm`.

**L2 global-ignore-differences — Every App Is OutOfSync (200 · advanced · 15m)** A cluster-wide mutation
(e.g. a label added to every Deployment by a "policy" CronJob) makes all apps OutOfSync; use
`resource.customizations.ignoreDifferences.apps_Deployment` instead of patching every app.

**L3 resource-exclusions — The Invisible Kind (200 · advanced · 15m)** `resource.exclusions` was set too wide
(excludes `ConfigMap` in all groups) → app shows Missing / never syncs config. Narrow it.

**L4 resource-actions — Restart Without kubectl (150 · intermediate · 10m)** Run the built-in `restart` action
on a Deployment via `argocd app actions run` (validator: pods restarted after setup time, app Synced).

**L5 custom-action — A Button For Maintenance (300 · expert · 25m)** Write a custom resource action (Lua) that
toggles a label/flag; run it.

**L6 cmp-plugin — Bring Your Own Tool (300 · expert · 25m)** A Config Management Plugin sidecar (busybox, a
`generate` command) is registered but its `discover` rule never matches the repo → app uses plain directory.
Fix plugin config / app `plugin.name`.

**L7 notifications — Tell Me When It Breaks (250 · advanced · 20m)** Configure `argocd-notifications-cm` with a
webhook service + `on-sync-failed` trigger and subscribe the app; a receiver in the cluster records calls
(verify an image from the allowed list can act as a receiver, e.g. nginx access log).

**L8 diff-normalization — The Defaulted Field (200 · advanced · 15m)** Git omits a field the API server
defaults in a non-normalized way, causing persistent diff; fix the manifest (explicit value) or use
`argocd app diff` to find it.

**L9 orphan-hunt-cli — Forensics With The CLI (200 · intermediate · 15m)** Something changed: use
`argocd app history`, `argocd app manifests --revision`, `argocd app diff --revision` to find which commit
introduced a broken value, then fix forward in Git.

**L10 reconcile-timeout — Why So Slow? (150 · intermediate · 10m)** `timeout.reconciliation` was set to `24h`
"to save CPU"; pushes are never noticed. Restore a sane value (component restart needed — explain why) and
consider webhooks.

---

## Module 10 — Production War Games (expert)

Multi-fault incidents across several apps/repos/projects. Each has 3–4 independent faults drawn from earlier
modules, a pager-style briefing, and a validator that checks the whole platform. Each must be unique.

**L1 black-friday — Black Friday Freeze (400 · expert · 30m)** sync window + HPA fight + pending release.
**L2 new-cluster-day — First Day On The New Cluster (400 · expert · 30m)** bootstrap root app, private repo
creds, missing namespace option, project destination.
**L3 helm-migration-gone-wrong — The Chart Migration (400 · expert · 30m)** release name drift, values file,
pruned PVC risk.
**L4 appset-outage — The Generator Ate The Fleet (450 · expert · 35m)** appset template bug deleted apps,
recover without rewriting history, protect deletion.
**L5 security-audit — Audit Findings (400 · expert · 30m)** default policy admin, plaintext secret in Git, repo
creds per repo, cluster resource `*/*`.
**L6 hooks-and-waves — The Migration That Ate Monday (450 · expert · 35m)** hook delete policy, RBAC wave, CRD
order, PostSync test.
**L7 drift-storm — Drift Storm (400 · expert · 30m)** shared resource, mutating field, hand-edited child app,
self-heal off.
**L8 grand-finale — Mission Control (500 · expert · 40m)** everything: app-of-apps + appset + projects + hooks,
five faults, full platform validation.
