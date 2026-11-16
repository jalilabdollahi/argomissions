# ArgoMissions — notes for Claude

- Levels are hand-authored; contract in docs/LEVEL_SPEC.md, curriculum in docs/CURRICULUM.md.
  The reference level is modules/module-1-basics/level-1-first-application.
- Test levels end-to-end with scripts/test_levels.py. Never use the user's global kube context or
  ~/.config/argocd: either `source scripts/agent_env.sh <slot>` (own kind cluster am-w<slot>, own ports) or
  `export KUBECONFIG=$PWD/.am-shared/kubeconfig ARGOCD_OPTS="--config $PWD/.am-shared/argocd/config"`
  (main cluster kind-argomissions, ports 9080/3300).
- Target: Argo CD v3.6.1 (pinned in scripts/cluster.sh), Gitea 28.4, kind / Kubernetes 1.37.
- Shell gotcha: level scripts run in bash; never name a variable `path` in code that might be sourced by zsh.
