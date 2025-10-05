# Synology CSI Deployment

## Current Status

- Flux now installs the upstream Synology CSI chart (`synology/synology-csi@0.10.1`).
- The driver runs in the `synology-csi` namespace and reads connection details from `client-info-secret` managed by ExternalSecret.
- A storage class named `synology-csi-synology-csi-synology-iscsi-storage` is created with `Delete` reclaim policy and `Immediate` binding mode.
- Volume snapshot support is enabled through `synology-csi-synology-csi-synology-snapshotclass`.

## Secret Template

The ExternalSecret at `flux/resources/synology-csi-external-secret.yaml` expects Vault data at `secret/democratic-csi/synology` with the following fields:

- `host` – DSM address, e.g. `172.16.0.189`
- `username` – Dedicated CSI user
- `password` – User password

This data is rendered into `client-info.yaml` for the chart. Update Vault and re-sync ExternalSecret if you rotate credentials.

## Operational Notes

- Kubernetes forbids mutating storage class parameters. When changing values such as the DSM address or target location, delete `synology-csi-synology-csi-synology-iscsi-storage` (and any PVCs using it) before applying new settings.
- If you need HTTPS connectivity, adjust `client-info.yaml` to set `https: true` and `port: 5001`, then update the HelmRelease with matching storage class parameters.
- Remove the legacy `democratic-csi` resources in the cluster (`kubectl delete ns democratic-csi`, `kubectl delete secret -n flux-system democratic-csi-driver-config`) once the Synology driver is verified.
- Verify deployment with:
  - `kubectl get pods -n synology-csi`
  - `kubectl get storageclass synology-csi-synology-csi-synology-iscsi-storage`
  - `kubectl get volumesnapshotclass synology-csi-synology-csi-synology-snapshotclass`
