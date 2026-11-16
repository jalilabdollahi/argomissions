# The Leaked Password

## What broke
A Secret manifest with a real SMTP password was committed in clear text. Argo CD did what it is built to do:
it applied it. Git now holds a credential that every clone, fork and CI cache has copied, and a password that has been
published is burnt, whatever you do to the file afterwards.

## Why Argo CD behaves this way
Argo CD deploys exactly what is in Git, and a Kubernetes Secret is only base64. There is nothing to protect the value
in the repository, so the answer is a different channel for the sensitive part. Deleting the file from Git does not
delete the object in the cluster: without `prune` Argo CD shows the Secret as "requires pruning" and leaves it
alone, and with `prune` it deletes the Secret it created (pods already running keep their old environment). Ownership
is recorded in the annotation `argocd.argoproj.io/tracking-id` (Argo CD 3.x default tracking); an object without it
is not part of the Application, so the Application can be Synced without it. Verified on v3.6.1 with an
Application that has automated sync and no prune.
Rewriting history (force-push, filter-repo) is a different tool: it destroys the audit trail, breaks every
other clone and still does not un-publish the password. Rotate first, scrub later and only deliberately.

## The fix
1. Remove `deploy/secret.yaml` in a normal commit. 2. Let Argo CD prune the owned Secret, or take it over by removing
the tracking annotation. 3. Create the Secret out of band with a new password (also changed at the provider).
4. Restart the pods that read it from the environment. In production prefer a mechanism that keeps the value out of
Git by design: Sealed Secrets or SOPS (encrypted in Git), or External Secrets / the Secrets Store CSI driver
(a reference in Git, the value in Vault or a cloud secret manager).

## In real life
Leaked-credential tickets are the most common trigger for adopting a secrets operator. The order matters: rotate
at the source first, then clean Git. Teams forget the restart and keep running on the burnt password for weeks.
Use pre-commit scanners and server-side push protection so the next one never reaches `main`.

## Commands worth remembering
```bash
git log --all -S'password-string' --oneline          # who ever committed it
argocd app resources APP                               # what the app owns
argocd app sync APP --prune
kubectl annotate secret NAME argocd.argoproj.io/tracking-id-
kubectl rollout restart deploy/NAME
```

## Common mistakes
- Changing the password in the YAML in Git: the new one leaks the same way.
- Force-pushing a scrubbed history and calling it fixed: the old password stays valid and copied everywhere.
- Rotating the Secret and forgetting the pods: they keep the old value until they restart.
