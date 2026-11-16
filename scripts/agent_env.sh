# shellcheck shell=bash
# Isolated environment for a level author / tester working in parallel with others.
#
#   source scripts/agent_env.sh <slot>      # slot = 1..8
#
# Each slot gets its own kind cluster (am-w<slot>) with its own Argo CD and Gitea, its own
# kubeconfig, argocd CLI config, sandbox and host ports:
#   Argo CD  http://localhost:909<slot>    Gitea  http://localhost:331<slot>    Gitea SSH  223<slot>
# The first `source` for a slot creates the cluster (about 3 minutes).
_slot="${1:?usage: source scripts/agent_env.sh <slot>}"
if [ -n "${ZSH_VERSION:-}" ]; then eval '_src="${(%):-%x}"'; else _src="${BASH_SOURCE[0]}"; fi
_root="$(cd "$(dirname "$_src")/.." && pwd)"
_state="$_root/.am-shared/agents/w${_slot}"
mkdir -p "$_state/sandbox" "$_state/argocd"
export ARGOMISSIONS_CLUSTER="am-w${_slot}"
export ARGOMISSIONS_CONTEXT="kind-am-w${_slot}"
export KUBECONFIG="$_state/kubeconfig"
export KUBECONFIG_GAME="$KUBECONFIG"
export AM_ARGOCD_CONFIG="$_state/argocd/config"
export ARGOCD_OPTS="--config $AM_ARGOCD_CONFIG"
export AM_ARGOCD_PORT="909${_slot}"
export AM_GIT_PORT="331${_slot}"
export AM_SSH_PORT="223${_slot}"
export ARGOMISSIONS_SANDBOX_ROOT="$_state/sandbox"
if ! kind get clusters 2>/dev/null | grep -qx "am-w${_slot}"; then
  bash "$_root/scripts/cluster.sh" create >"$_state/cluster-create.log" 2>&1 \
    || { echo "cluster creation failed, see $_state/cluster-create.log"; return 1; }
fi
[ -s "$KUBECONFIG" ] || kind get kubeconfig --name "am-w${_slot}" >"$KUBECONFIG"
cd "$_root" || return 1
unset _slot _root _state _src
