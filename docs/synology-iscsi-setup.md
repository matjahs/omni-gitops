# Synology DS723+ iSCSI Configuration for Kubernetes

## Overview
This guide configures Synology DS723+ as an iSCSI storage backend for Kubernetes using democratic-csi.

## Prerequisites
- Synology DS723+ running DSM 7.x
- Talos Linux cluster with `iscsi-tools` extension installed
- Network connectivity between Kubernetes nodes and Synology (172.16.20.0/24)

## Part 1: Synology iSCSI Configuration

### 1. Enable iSCSI Service
1. Open **Control Panel** → **File Services** → **Advanced**
2. Go to **iSCSI** tab
3. Check **Enable iSCSI service**
4. Click **Apply**

### 2. Create Storage Pool (if not exists)
1. Open **Storage Manager**
2. **Storage Pool** → **Create**
3. Select RAID type (recommended: SHR or RAID 1 for redundancy)
4. Follow wizard to create pool

### 3. Create iSCSI Target
1. Open **SAN Manager**
2. Go to **iSCSI Target** tab
3. Click **Create**
4. Configure:
   - **Name**: `kubernetes-storage`
   - **IQN**: `iqn.2000-01.com.synology:kubernetes-storage` (auto-generated)
   - **CHAP Authentication**:
     - Check **Enable CHAP**
     - Username: `k8sadmin` (choose your own)
     - Password: (secure password, min 12 characters)
   - **Mutual CHAP**: Leave disabled for simplicity
5. Click **Next** → **Apply**

### 4. Create iSCSI LUN
1. In **SAN Manager**, go to **LUN** tab
2. Click **Create**
3. Select **Create LUN on RAID**
4. Configure:
   - **Location**: Select your storage volume (e.g., `volume1`)
   - **Name**: `k8s-dynamic-storage`
   - **Capacity**: Start with 500 GB (democratic-csi will carve volumes from this)
   - **Allocation**: **Thick provisioning** (better performance)
   - **Target**: Select the `kubernetes-storage` target created above
5. Click **Next** → **Apply**

### 5. Configure Network Access Control
1. Still in **SAN Manager**, click on your iSCSI target
2. Click **Edit** → **Advanced**
3. Under **Network Portal**, ensure it listens on the correct network interface
4. Under **Allowed initiators**:
   - Option 1: Add each Kubernetes node's IQN individually (more secure)
   - Option 2: Leave empty to allow all (simpler for lab)
5. Click **OK**

### 6. Enable SSH Access (for democratic-csi management)
1. Go to **Control Panel** → **Terminal & SNMP**
2. Enable **SSH service** (Port 22)
3. Click **Apply**

### 7. Create SSH Key for Kubernetes Access
1. SSH into Synology: `ssh admin@<synology-ip>`
2. Create .ssh directory if not exists:
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   ```
3. On your workstation, generate SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/synology-k8s -C "kubernetes-csi"
   ```
4. Copy public key to Synology:
   ```bash
   ssh-copy-id -i ~/.ssh/synology-k8s.pub admin@<synology-ip>
   ```
5. Test key-based login:
   ```bash
   ssh -i ~/.ssh/synology-k8s admin@<synology-ip>
   ```

## Part 2: Kubernetes Configuration

### 1. Create Kubernetes Secret for Synology Access

Create file: `flux/secrets/democratic-csi-synology-secret.yaml`

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: democratic-csi-synology
  namespace: democratic-csi
type: Opaque
stringData:
  # SSH private key for Synology access
  ssh-privatekey: |
    -----BEGIN OPENSSH PRIVATE KEY----- # pragma: allowlist secret
    <paste your private key content here>
    -----END OPENSSH PRIVATE KEY-----
  # iSCSI CHAP credentials
  chap-username: k8sadmin
  chap-password: <your-chap-password>
```

**Important**: Use External Secrets Operator or Sealed Secrets in production!

### 2. Information Needed for democratic-csi Configuration

Gather these details from your Synology:

- **Synology IP**: `<synology-ip>`
- **iSCSI Target IQN**: `iqn.2000-01.com.synology:kubernetes-storage`
- **SSH Username**: `admin`
- **CHAP Username**: `k8sadmin`
- **Volume Path**: `/volume1` (or your configured volume)
- **LUN Base Path**: `/volume1/k8s-dynamic-storage`

## Verification

### Test iSCSI connectivity from a Kubernetes node:

```bash
# SSH into a Talos node
talosctl shell --nodes 172.16.20.51

# Discover iSCSI targets
iscsiadm -m discovery -t st -p <synology-ip>:3260

# Expected output:
# <synology-ip>:3260,1 iqn.2000-01.com.synology:kubernetes-storage
```

### Test SSH access from Kubernetes (create test pod):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ssh-test
spec:
  containers:
  - name: test
    image: alpine
    command: ["/bin/sh", "-c", "apk add openssh-client && ssh -i /ssh/key -o StrictHostKeyChecking=no admin@<synology-ip> 'echo Connection successful'"]
    volumeMounts:
    - name: ssh-key
      mountPath: /ssh
  volumes:
  - name: ssh-key
    secret:
      secretName: democratic-csi-synology
      items:
      - key: ssh-privatekey
        path: key
        mode: 0600
```

## Troubleshooting

### iSCSI connection fails
- Check firewall on Synology (Port 3260 must be open)
- Verify network connectivity: `ping <synology-ip>` from nodes
- Check initiator IQN matches allowed list in SAN Manager

### SSH authentication fails
- Verify key permissions: `chmod 600 ~/.ssh/synology-k8s`
- Check authorized_keys on Synology: `cat ~/.ssh/authorized_keys`
- Try password authentication first to rule out connectivity issues

### LUN provisioning fails
- Ensure base LUN has sufficient free space
- Check Synology logs: **Log Center** → **System**
- Verify SSH user has admin privileges

## Next Steps

Once Synology is configured:
1. Deploy democratic-csi via Flux
2. Create StorageClass
3. Test PVC provisioning
4. Migrate existing workloads
