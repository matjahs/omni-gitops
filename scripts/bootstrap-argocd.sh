#!/usr/bin/env bash
set -euo pipefail
# Bootstrap Argo CD (install manifests + self-managing Application)
# Usage: scripts/bootstrap-argocd.sh [git_repo_url] [git_revision]
# Defaults use repo origin and HEAD main.

REPO_URL=${1:-"https://github.com/matjahs/omni-gitops.git"}
REVISION=${2:-"HEAD"}
APP_FILE=applications/argocd-config.yaml

kubectl get ns argocd >/dev/null 2>&1 || kubectl create namespace argocd

# Install upstream Argo CD core (cluster install) via kustomize base overlay
if ! kubectl get deploy -n argocd argocd-repo-server >/dev/null 2>&1; then
  echo "Applying Argo CD manifests..."
  kubectl kustomize apps/argocd/overlays/production | kubectl apply -f -
fi

echo "Waiting for argocd-repo-server deployment..."
kubectl rollout status deploy/argocd-repo-server -n argocd --timeout=300s

echo "Applying self-managing Application (${APP_FILE})..."
# Patch repo URL/revision if different
TMP=$(mktemp)
cp ${APP_FILE} "$TMP"
sed -i '' "s#repoURL: .*#repoURL: ${REPO_URL//#/\#}#" "$TMP" || true
sed -i '' "s#targetRevision: .*#targetRevision: ${REVISION}#" "$TMP" || true
kubectl apply -f "$TMP"
rm -f "$TMP"

echo "Waiting for Application sync..."
for i in {1..60}; do
  PHASE=$(kubectl get application.argoproj.io/argocd-config -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  if [ "$PHASE" = "Synced" ]; then
    echo "Argo CD Application synced."; break
  fi
  sleep 5
  echo "Sync status: ${PHASE:-unknown}";
  if [ $i -eq 60 ]; then echo "Timeout waiting for Argo CD Application sync"; exit 1; fi
done

echo "Bootstrap complete."