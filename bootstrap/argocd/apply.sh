#!/bin/sh
VALUES="values.yaml"

helm template \
  --dependency-update \
  --include-crds \
  --namespace argocd \
  --values "$VALUES" \
  argocd . \
  | kubectl apply -n argocd -f -

kubectl -n argocd \
  wait \
  --timeout=60s \
  --for condition=established \
  crd/applications.argoproj.io \
  crd/applicationsets.argoproj.io
