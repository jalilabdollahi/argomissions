# Host Key Verification Failed

## What broke
The Application read its repository over SSH with a valid deploy key, but Argo CD had never been told which host key the
Git server presents. SSH clients refuse servers they do not know, so the handshake failed with
`knownhosts: key is unknown` before the deploy key was ever offered. The error mentions neither keys nor
authentication: it is about trust in the *server*.

## Why Argo CD behaves this way
Like `ssh` itself, the repo-server checks the server's host key against a known-hosts list. Argo CD keeps the list in the
ConfigMap `argocd-ssh-known-hosts-cm` (key `ssh_known_hosts`, mounted into the repo-server at `/app/config/ssh/ssh_known_hosts`),
pre-filled with the public hosts of GitHub, GitLab, Bitbucket, Azure DevOps. A self-hosted Git server must be added by you:
`argocd cert add-ssh --batch` (or the UI, Settings > Certificates) edits the ConfigMap for you, one `host keytype key` line per key.
Host keys are what protects a deploy key from being handed to an impostor, so a *mismatch* is rejected just like an unknown key.
Because the file is mounted from a ConfigMap, the repo-server notices a change after the kubelet's volume refresh, which can
take up to a minute; a refresh before that still shows the old error.

## The fix
Collect the Git server's host keys (`ssh-keyscan`, or better a fingerprint you verified out of band), register them as SSH
known hosts, and refresh the Application. The repository Secret and the Application stay exactly as they were.

## In real life
`insecure-ignore-host-key` ("it works!") removes the only check against a spoofed Git host and ends up in production
because nobody remembers it. Manage known hosts declaratively (the ConfigMap in Git, or Helm values `configs.ssh.knownHosts`)
so a rebuilt Argo CD does not lose it. After a Git server migration its host keys change and every SSH repo breaks the same way.
Note the host name in the entry must match the URL exactly (a non-standard port is written `[host]:port`).

## Commands worth remembering
```bash
argocd cert list --cert-type ssh
ssh-keyscan HOST | argocd cert add-ssh --batch
argocd cert rm --cert-type ssh HOST
kubectl -n argocd get cm argocd-ssh-known-hosts-cm -o yaml
```

## Common mistakes
- Enabling `--insecure-ignore-host-key` on the repo, or switching the app to HTTP.
- Registering the host with a wrong name (an entry for `localhost:2222` does not cover `gitea.gitea.svc.cluster.local`).
- Testing before the repo-server has refreshed the mounted ConfigMap and concluding the fix failed.
