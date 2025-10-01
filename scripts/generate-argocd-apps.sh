#!/bin/bash
# Script: generate-argocd-apps.sh
# Description: Generate ArgoCD Application manifests from a template and input values
# Usage: ./generate-argocd-apps.sh <app-name> <repo-url> <path> <dest-namespace>

echo "Generated ${APP_NAME}-application.yaml"

set -euo pipefail

read -rp "Enter application name: " APP_NAME
read -rp "Destination namespace: " DEST_NAMESPACE

PS3="Select application source type: "
select TYPE in "Manifest URL" "Helm Chart"; do
  case $TYPE in
    "Manifest URL")
      read -rp "Enter manifest URL (e.g. https://...): " MANIFEST_URL
      cat <<EOF > "${APP_NAME}-application.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${MANIFEST_URL}
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: ${DEST_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
      echo "Generated ${APP_NAME}-application.yaml for manifest URL."
      break
      ;;
    "Helm Chart")
      read -rp "Helm repo URL: " HELM_REPO
      read -rp "Chart name: " HELM_CHART
      read -rp "Chart version (or leave blank for latest): " HELM_VERSION
      cat <<EOF > "${APP_NAME}-application.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${HELM_REPO}
    chart: ${HELM_CHART}
    targetRevision: ${HELM_VERSION:-latest}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${DEST_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
      echo "Generated ${APP_NAME}-application.yaml for Helm chart."
      break
      ;;
    *)
      echo "Invalid selection."
      ;;
  esac
done
