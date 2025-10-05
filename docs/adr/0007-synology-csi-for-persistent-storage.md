# ADR-0007: Synology CSI Driver for Persistent Storage

## Status

Accepted

## Date

2025-10-05

## Context

The cluster needed a reliable persistent storage solution for stateful workloads (databases, monitoring, etc.). Three major storage backends were evaluated over time:

###Previous implementations:

1. **Rook-Ceph** (September 2025 - October 2025)
   - Distributed storage with replica=2
   - Required 3+ nodes for quorum
   - High resource overhead (memory, CPU, network)
   - Complex troubleshooting when things went wrong
   - Node failures caused cascading issues

2. **Democratic-CSI** (October 1-4, 2025)
   - Connected to Synology NAS via iSCSI
   - Required Talos iscsi-tools extension on all nodes
   - Complex driver configuration with CHAP authentication
   - Struggled with DSM 7.x compatibility (FILE LUN type issues)
   - Multiple failed attempts to get working correctly

### Options Considered

#### Option 1: Continue with Rook-Ceph
Keep the distributed Ceph cluster running.

**Pros:**
- Already deployed and somewhat working
- True distributed storage
- Cloud-native solution
- No external dependencies

**Cons:**
- High resource overhead (3+ GB RAM per OSD)
- Network-intensive replication
- Complex troubleshooting
- Requires minimum 3 nodes for resilience
- OSD crashes caused cluster-wide issues
- Over-engineered for homelab scale

#### Option 2: Refine Democratic-CSI
Continue debugging the Democratic-CSI implementation.

**Pros:**
- Leverages existing Synology hardware
- Cost-effective (no new hardware)
- Mature storage backend (Synology DSM)

**Cons:**
- Required Talos extension (iscsi-tools)
- Complex configuration (CHAP, IQN, driver config)
- DSM 7.x compatibility issues
- Multiple namespace requirements (ExternalSecret in flux-system, app elsewhere)
- Troubleshooting difficult (driver config opaque)
- FILE vs BLUN type confusion

#### Option 3: Official Synology CSI Driver
Use the official Synology CSI driver with simpler configuration.

**Pros:**
- Official support from Synology
- Simpler configuration (no manual driver config)
- Built-in snapshot support
- Better DSM 7.x compatibility
- Active maintenance and updates
- Community usage and documentation

**Cons:**
- Still requires iSCSI (Talos extension needed)
- Less flexible than Democratic-CSI
- Synology-specific (vendor lock-in)

#### Option 4: Local Path Provisioner
Use hostPath-based local storage.

**Pros:**
- Simplest solution
- No external dependencies
- Fast performance

**Cons:**
- No data replication
- Not portable across nodes
- Data loss if node fails
- Not suitable for production workloads

## Decision

We will use the **official Synology CSI driver** (Option 3) for persistent storage:

- **Driver**: `synology-csi` (Helm chart v0.10.1)
- **Backend**: Synology DS723+ NAS via iSCSI
- **Storage Location**: `/volume1/k8s`
- **Storage Class**: `synology-iscsi-storage` (ReclaimPolicy: Delete)
- **Snapshot Class**: `synology-snapshotclass` (DeletionPolicy: Delete)
- **Authentication**: Managed via ExternalSecret (Vault → Kubernetes Secret)

### Migration from Democratic-CSI

1. Remove Democratic-CSI HelmRelease and all related resources
2. Install official Synology CSI Helm chart
3. Configure via HelmRelease values (no manual driver config)
4. Use ExternalSecret for credentials (username/password only)
5. Disable unused storage classes (NFS, SMB, default iSCSI)
6. Enable custom `synology-iscsi-storage` with proper DSM parameters

## Consequences

### Positive

- **Simpler configuration**: HelmRelease values vs manual driver config
- **Official support**: Maintained by Synology
- **Better compatibility**: Works with DSM 7.x out of the box
- **Cleaner secrets management**: Just username/password (no complex CHAP/IQN secrets)
- **Snapshot support**: Built-in VolumeSnapshot integration
- **Active community**: Well-documented, actively used
- **Easier troubleshooting**: Standard CSI driver patterns
- **Less resource overhead**: No distributed storage complexity

### Negative

- **Still requires iSCSI**: Talos extension needed (same as Democratic-CSI)
- **Vendor lock-in**: Synology-specific driver
- **Single point of failure**: NAS is SPOF (mitigated by Synology RAID)
- **Network dependency**: Storage requires network to NAS
- **Limited to Synology**: Can't easily migrate to other storage vendors

### Neutral

- **Performance**: iSCSI over 10GbE network (adequate for homelab)
- **Capacity**: Limited by NAS capacity (expandable with drives)
- **Backup**: Relies on Synology snapshot/replication features

### Migration Path Taken

**Removal of Rook-Ceph** (commit fc02fc6, Oct 5):
- Deleted `apps/rook-ceph/` (operator, cluster, dashboard)
- Removed ArgoCD Application
- Updated dependent apps to use `local-path` temporarily
- Removed HTTPRoutes for Ceph dashboard

**Attempt with Democratic-CSI** (commits cabe36f → ca44f97, Oct 1-5):
- Multiple iterations trying to get working
- Driver config secrets, CHAP authentication
- DSM 7.x FILE LUN type issues
- ExternalSecret namespace complications

**Final adoption of Synology CSI** (commit ca44f97, Oct 5):
- Removed Democratic-CSI completely
- Installed official `synology-csi` Helm chart
- Configured storage class with DSM-specific parameters
- Set up ExternalSecret for credentials
- Verified with test PVC

### Configuration Details

```yaml
# flux/apps/synology-csi/helmrelease.yaml
storageClasses:
  synology-iscsi-storage:
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
    parameters:
      fsType: ext4
      dsm: 172.16.0.189
      location: /volume1/k8s

volumeSnapshotClasses:
  synology-snapshotclass:
    deletionPolicy: Delete
```

### Verification

Test PVC provisioning:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: synology-iscsi-storage
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
# Should show Bound status
```

## References

- [Synology CSI Driver](https://github.com/SynologyOpenSource/synology-csi)
- [Synology CSI Helm Chart](https://christian-schlichtherle.github.io/synology-csi-chart/)
- [Democratic-CSI](https://github.com/democratic-csi/democratic-csi) (previous attempt)
- [Rook-Ceph Documentation](https://rook.io/docs/rook/latest-release/Getting-Started/intro/) (previous implementation)
- Commits: fc02fc6 (remove rook-ceph), ca44f97 (adopt synology-csi)
