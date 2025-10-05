# Democratic-CSI Next Steps

## Current Status

We've made significant progress but hit a configuration complexity issue:

### ✅ Completed
1. Synology DS723+ iSCSI target configured (`iqn.2000-01.com.synology:kubernetes-storage`)
2. 500GB base LUN created (`kubernetes-dynamic-pv`)
3. Talos `iscsi-tools` extension installed on all nodes
4. Vault populated with credentials
5. Democratic-CSI Helm configuration created

### ❌ Blocking Issue

The democratic-csi Helm chart expects driver configuration in a specific format that doesn't align well with ExternalSecret templating. The issue:

- Democratic-CSI expects `driver.config` as a nested YAML structure in Helm values
- ExternalSecret can template secrets but not inject nested structures into HelmRelease values
- Current approach tried to provide driver config via `valuesFrom` secret reference, causing parsing errors

## Recommended Solutions

### Option 1: Use ArgoCD Vault Plugin (Cleanest)

Since you're planning to use ArgoCD for applications anyway (Flamingo architecture), use ArgoCD Vault Plugin to inject secrets directly into the Helm values:

1. Install ArgoCD with Vault Plugin (you already have ArgoCD)
2. Create `flux/releases/democratic-csi.yaml` with placeholders:
   ```yaml
   values:
     driver:
       config:
         driver: synology-iscsi
         httpConnection:
           host: <path:secret/data/democratic-csi/synology#host>
           username: <path:secret/data/democratic-csi/synology#username>
           password: <path:secret/data/democratic-csi/synology#password>
         iscsi:
           chap:
             username: <path:secret/data/democratic-csi/synology#chap_username>
             password: <path:secret/data/democratic-csi/synology#chap_password>
   ```

3. ArgoCD Vault Plugin will replace placeholders at deploy time

### Option 2: Manual Secret Creation (Quickest)

Create the Helm values secret manually with correct format:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: democratic-csi-driver-config
  namespace: flux-system
stringData:
  values.yaml: |
    driver:
      config:
        driver: synology-iscsi
        httpConnection:
          protocol: http
          host: 172.16.0.189
          port: 5000
          username: vsphere
          password: "VMware123!VMware123!VMware123!VMware123!"
          allowInsecure: true
        synology:
          volume: /volume1
        iscsi:
          targetPortal: "172.16.0.189:3260"
          targetPortals: []
          interface: ""
          namePrefix: "csi-"
          nameSuffix: "-cluster1"
          targetGroups:
            - targetGroupID: 1
          lunTemplate: "iqn.2000-01.com.synology:kubernetes-storage"
          targetTemplate: "iqn.2000-01.com.synology:kubernetes-storage"
          chap:
            username: k8siscsi
            password: "VMware123!K8sStorage"
            mutual_username: ""
            mutual_password: ""
          lunGroupAuthType: CHAP
          lungroupPrefix: "csi-"
          lunIdMin: 1
          lunIdMax: 255
EOF
```

Then update HelmRelease:
```yaml
spec:
  valuesFrom:
    - kind: Secret
      name: democratic-csi-driver-config
      valuesKey: values.yaml
```

### Option 3: Use SealedSecrets (GitOps-friendly)

1. Install Sealed Secrets controller
2. Create the secret with correct format
3. Seal it with `kubeseal`
4. Commit sealed secret to Git
5. Controller automatically unseals in cluster

## Immediate Action Plan

Since this is taking longer than expected and you have other priorities (monitoring, migration plan), I recommend:

1. **For now**: Continue using `local-path-provisioner` - it works for monitoring
2. **Later**: Come back to democratic-csi with Option 1 (ArgoCD Vault Plugin) when you're setting up ArgoCD
3. **Monitoring fix**: Let's quickly fix the Prometheus permissions issue with local-path storage
4. **Migration plan**: Create the ArgoCD → Flux migration document

Would you like me to:
- A) Fix the Prometheus permission issue with current local-path storage
- B) Continue debugging democratic-csi (may take more time)
- C) Skip to creating the ArgoCD → Flux migration plan

My recommendation is **A then C** - get monitoring working, document the migration plan, then circle back to democratic-csi when setting up ArgoCD with Vault Plugin.

## Quick Fix for Prometheus

If you choose option A, here's the one-line fix:

```bash
kubectl patch statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus \
  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/securityContext/fsGroup", "value":2000}]'
```

This sets the correct filesystem group so Prometheus can write to the volume.
