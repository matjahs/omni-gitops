# Democratic-CSI Deployment Guide

## Current Status

✅ **Completed:**
- Synology DS723+ iSCSI target configured
  - Target IQN: `iqn.2000-01.com.synology:kubernetes-storage`
  - LUN: `kubernetes-dynamic-pv` (500 GB, thick provisioned)
  - CHAP authentication enabled
- Democratic-CSI Flux configuration pushed to Git
- HelmRepository, HelmRelease, and ExternalSecret created

⏳ **Pending:**
1. Install Talos `iscsi-tools` extension on all cluster nodes
2. Populate Vault with Synology credentials
3. Verify democratic-csi deployment
4. Test PVC provisioning

---

## Step 1: Install iSCSI Extension on Talos Nodes

### Option A: Via Omni UI (Recommended)

1. Log into Omni Console: https://omni.siderolabs.com
2. Navigate to your cluster → **Config** → **Machine Extensions**
3. Click **Add Extension**
4. Enter: `siderolabs/iscsi-tools`
5. Select **All Nodes** (control-plane + workers)
6. Click **Apply**
7. Wait for nodes to reboot (~5 minutes per node rolling restart)

### Option B: Via omnictl

```bash
# Get current cluster template
omnictl cluster template status matjahs-cluster1

# Export template
omnictl cluster template export matjahs-cluster1 > cluster-template.yaml

# Edit to add extension under each machine class:
# machineClass:
#   ...
#   extensions:
#     - image: ghcr.io/siderolabs/iscsi-tools:v0.1.4

# Apply updated template
omnictl cluster template sync -f cluster-template.yaml
```

### Verification

After nodes reboot, verify iSCSI tools are available:

```bash
# Test from one node
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
apk add open-iscsi
iscsiadm --version
```

Or check from Talos directly:

```bash
talosctl --nodes 172.16.20.51 ls /usr/local/sbin/iscsiadm
```

---

## Step 2: Populate Vault with Synology Credentials

Run the setup script with your credentials:

```bash
export VAULT_ADDR="http://172.16.0.4:8200"
export VAULT_TOKEN="<your-vault-token>"

export SYNOLOGY_USERNAME="vsphere"
export SYNOLOGY_PASSWORD="VMware123!VMware123!VMware123!VMware123!"
export CHAP_USERNAME="k8siscsi"
export CHAP_PASSWORD="VMware123!K8sStorage"

./scripts/setup-democratic-csi-vault-secret.sh
```

### Verify Vault Secret

```bash
vault kv get secret/democratic-csi/synology
```

Expected output should show all fields:
- `host`: 172.16.0.189
- `username`: vsphere
- `password`: (hidden)
- `volume`: /volume1
- `iqn`: iqn.2000-01.com.synology:kubernetes-storage
- `chap_username`: k8siscsi
- `chap_password`: (hidden)

---

## Step 3: Monitor Democratic-CSI Deployment

### Watch Flux Reconciliation

```bash
# Watch Flux kustomization
flux get kustomizations --watch

# Watch HelmRelease
flux get helmreleases -n flux-system democratic-csi-iscsi --watch
```

### Check Democratic-CSI Resources

```bash
# Check namespace creation
kubectl get namespace democratic-csi

# Check ExternalSecret
kubectl get externalsecret -n democratic-csi democratic-csi-synology

# Check generated secret
kubectl get secret -n democratic-csi democratic-csi-synology

# Check democratic-csi pods
kubectl get pods -n democratic-csi -w
```

Expected pods:
- `democratic-csi-iscsi-controller-xxxxx` (1 replica)
- `democratic-csi-iscsi-node-xxxxx` (1 per node = 6 replicas)

### Check Logs

```bash
# Controller logs
kubectl logs -n democratic-csi deploy/democratic-csi-iscsi-controller -c csi-driver

# Node driver logs (on specific node)
kubectl logs -n democratic-csi daemonset/democratic-csi-iscsi-node -c csi-driver
```

### Verify StorageClass

```bash
kubectl get storageclass synology-iscsi
```

Expected output:
```
NAME              PROVISIONER                 RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION
synology-iscsi    org.democratic-csi.iscsi    Delete          Immediate           true
```

---

## Step 4: Test PVC Provisioning

Create a test PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-synology-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: synology-iscsi
  resources:
    requests:
      storage: 1Gi
```

Apply and verify:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-synology-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: synology-iscsi
  resources:
    requests:
      storage: 1Gi
EOF

# Watch PVC status
kubectl get pvc test-synology-pvc -w
```

Expected progression:
1. `Pending` → `Bound` (should take < 30 seconds)

Check PV details:

```bash
kubectl get pv
kubectl describe pvc test-synology-pvc
```

### Test with a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-synology-pod
  namespace: default
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh", "-c", "echo 'Testing iSCSI volume' > /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: storage
          mountPath: /data
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: test-synology-pvc
```

Apply and verify:

```bash
kubectl apply -f <test-pod.yaml>
kubectl get pod test-synology-pod -w

# Once running, verify data
kubectl exec test-synology-pod -- cat /data/test.txt
# Should output: Testing iSCSI volume

# Check iSCSI session on the node
NODE=$(kubectl get pod test-synology-pod -o jsonpath='{.spec.nodeName}')
talosctl --nodes $NODE iscsiadm -m session
```

### Cleanup Test Resources

```bash
kubectl delete pod test-synology-pod
kubectl delete pvc test-synology-pvc
```

---

## Troubleshooting

### iSCSI Extension Not Found

**Symptom:** Node pods crash with "iscsiadm: command not found"

**Solution:**
1. Verify extension installed: `talosctl --nodes <node-ip> get extensions`
2. Check Talos version compatibility (requires v1.3+)
3. Reboot nodes if extension was just added

### PVC Stuck in Pending

**Symptom:** PVC remains in `Pending` state

**Debug steps:**

```bash
# Check controller logs
kubectl logs -n democratic-csi deploy/democratic-csi-iscsi-controller -c csi-driver --tail=50

# Check events
kubectl describe pvc <pvc-name>

# Common issues:
# 1. Vault secret not populated → Check ExternalSecret status
# 2. Wrong Synology credentials → Verify in Vault
# 3. iSCSI target unreachable → Test: iscsiadm -m discovery -t st -p 172.16.0.189:3260
# 4. CHAP auth failure → Verify CHAP username/password in Synology and Vault match
```

### ExternalSecret Not Creating Secret

**Symptom:** `democratic-csi-synology` secret doesn't exist

**Debug steps:**

```bash
# Check ExternalSecret status
kubectl describe externalsecret -n democratic-csi democratic-csi-synology

# Check ClusterSecretStore
kubectl describe clustersecretstore vault-backend

# Verify Vault secret exists
vault kv get secret/democratic-csi/synology

# Check external-secrets-operator logs
kubectl logs -n external-secrets deploy/external-secrets
```

### Node Driver Pods CrashLoopBackOff

**Symptom:** `democratic-csi-iscsi-node-xxxxx` pods crashing

**Debug steps:**

```bash
# Check pod logs
kubectl logs -n democratic-csi daemonset/democratic-csi-iscsi-node -c csi-driver

# Common issues:
# 1. Missing hostPID: true → Check HelmRelease values
# 2. Wrong iscsiadm path → Verify /usr/local/sbin/iscsiadm exists on node
# 3. Permission denied → Check namespace pod-security label is 'privileged'
```

### Synology Connection Issues

**Test connectivity from a node:**

```bash
# Create debug pod on specific node
kubectl run -it --rm --restart=Never --image=alpine debug-iscsi -- sh

# Inside pod:
apk add open-iscsi
iscsiadm -m discovery -t st -p 172.16.0.189:3260

# Expected output:
# 172.16.0.189:3260,1 iqn.2000-01.com.synology:kubernetes-storage
```

If discovery fails:
1. Check firewall on Synology (port 3260)
2. Verify network connectivity: `ping 172.16.0.189`
3. Check Synology iSCSI service is running
4. Verify target is not restricted to specific initiator IQNs

---

## Next Steps

After successful testing:

1. **Migrate Monitoring Stack** to use democratic-csi:
   - Update monitoring StorageClass to `synology-iscsi`
   - Delete old local-path PVCs
   - Let ArgoCD recreate with new storage

2. **Set as Default StorageClass** (optional):
   ```bash
   kubectl patch storageclass synology-iscsi -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
   ```

3. **Remove local-path-provisioner**:
   - After all workloads migrated
   - Delete from Flux kustomization

4. **Configure Volume Snapshots** (optional):
   - Test VolumeSnapshot creation
   - Set up snapshot schedules with Velero or similar

---

## References

- [Democratic-CSI Documentation](https://github.com/democratic-csi/democratic-csi)
- [Talos Linux iSCSI Guide](https://www.talos.dev/v1.10/kubernetes-guides/configuration/storage/)
- [Synology iSCSI Setup Guide](docs/synology-iscsi-setup.md)
