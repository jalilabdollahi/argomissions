#!/bin/bash
# ArgoMissions installer: checks tools, creates the venv and the kind cluster with Gitea + Argo CD.
# Safe to re-run: it repairs a half-finished install. Your ~/.kube/config is never changed.
set -euo pipefail
cd "$(dirname "$0")"

echo "🐙 ArgoMissions Installation"
echo "============================"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ $1 not found. Install: $2"; exit 1; }; }
need docker  "https://www.docker.com/products/docker-desktop/ (and start it)"
need kind    "brew install kind"
need kubectl "brew install kubectl"
need argocd  "brew install argocd"
need git     "xcode-select --install  (or brew install git)"
need jq      "brew install jq"
need curl    "brew install curl"
need python3 "brew install python"
docker info >/dev/null 2>&1 || { echo "❌ Docker is not running. Start Docker Desktop and retry."; exit 1; }
echo "✅ $(argocd version --client --short 2>/dev/null | head -1)"

if [ ! -x venv/bin/python3 ]; then
  python3 -m venv venv
fi
venv/bin/python3 -m pip install -q --disable-pip-version-check -r requirements.txt
echo "✅ Python packages installed"

bash scripts/cluster.sh create

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅  ArgoMissions is ready!"
echo "   Play:            ./play.sh"
echo "   Second terminal: source ./env.sh"
echo "   Argo CD UI:      http://localhost:9080   (admin / argomissions)"
echo "   Gitea:           http://localhost:3300   (player / argomissions)"
echo "════════════════════════════════════════════════════════"
