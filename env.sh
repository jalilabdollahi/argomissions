# shellcheck shell=bash
# Source this in your second terminal:   source ./env.sh
# kubectl and argocd then talk to the ArgoMissions cluster only (your ~/.kube/config and
# ~/.config/argocd are not used in this shell), and you land in the level workspace.
if [ -n "${ZSH_VERSION:-}" ]; then eval '_am_src="${(%):-%x}"'; else _am_src="${BASH_SOURCE[0]}"; fi
_am_root="$(cd "$(dirname "$_am_src")" && pwd)"
export KUBECONFIG="$_am_root/.am-shared/kubeconfig"
export ARGOCD_OPTS="--config $_am_root/.am-shared/argocd/config"
export AM_ROOT="$_am_root"
alias am-workspace='cd "$AM_ROOT/sandbox/current"'
if [ -z "${_AM_PROMPT_SET:-}" ]; then
  if [ -n "${ZSH_VERSION:-}" ]; then PROMPT="%F{cyan}(argo)%f $PROMPT"; else PS1="(argo) $PS1"; fi
  export _AM_PROMPT_SET=1
fi
cd "$_am_root/sandbox/current" 2>/dev/null || cd "$_am_root"
echo "🐙 ArgoMissions shell: kubectl + argocd → game cluster only.  am-workspace = back to the level workspace."
echo "   Argo CD UI http://localhost:9080 (admin / argomissions)   Gitea http://localhost:3300 (player / argomissions)"
unset _am_src _am_root
