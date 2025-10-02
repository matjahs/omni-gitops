# Monitoring & Observability

This platform uses Prometheus and Grafana for cluster and application monitoring, deployed via ArgoCD.

## Quick Start

To deploy the monitoring stack:

```bash
kubectl apply -f applications/monitoring.yaml
```

Or, use ArgoCD to sync the application:

```bash
argocd app sync monitoring
```

## Accessing Dashboards

- **Grafana:** https://grafana.apps.lab.mxe11.nl
- **Prometheus:** https://prometheus.apps.lab.mxe11.nl

## Customizing Monitoring

Edit the values in:
- `apps/monitoring/kube-prometheus-stack/overlays/production/values.yaml`

## Alerting

Prometheus Alertmanager is included. You can add custom alert rules in the values file or via ConfigMaps.

## Troubleshooting

- Check ArgoCD sync status: `kubectl get applications -n argocd`
- Check monitoring pods: `kubectl get pods -n monitoring`
- View logs: `kubectl logs -n monitoring <pod>`

## References
- [Kube-Prometheus-Stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
