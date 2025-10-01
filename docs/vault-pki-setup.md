# Vault PKI Integration Setup

This guide covers setting up HashiCorp Vault's PKI secrets engine and integrating it with cert-manager for automated certificate management.

## Prerequisites

- HashiCorp Vault server running at `http://172.16.0.4:8200`
- Vault CLI or API access with admin privileges
- cert-manager installed in the cluster
- External Secrets Operator configured with Vault

## Architecture

```
┌─────────────────┐
│   Root CA       │ (External - ADCS or existing Root)
│   (Optional)    │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Vault PKI      │ ← Intermediate CA
│  (Intermediate) │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  cert-manager   │ ← Requests certificates
│  (Kubernetes)   │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Applications   │ ← Uses certificates
└─────────────────┘
```

## Step 1: Enable PKI Secrets Engine in Vault

Connect to your Vault server and enable the PKI secrets engine:

```bash
# Set Vault address and token
export VAULT_ADDR="http://172.16.0.4:8200"
export VAULT_TOKEN="your-vault-token"

# Enable PKI secrets engine at pki/ path
vault secrets enable pki

# Tune the engine to allow certificates with longer TTLs (10 years for root)
vault secrets tune -max-lease-ttl=87600h pki
```

## Step 2: Generate Root CA (Option A - Self-Signed)

If you don't have an existing Root CA:

```bash
# Generate root certificate
vault write -field=certificate pki/root/generate/internal \
    common_name="Lab Root CA" \
    issuer_name="lab-root" \
    ttl=87600h \
    > lab_root_ca.crt

# Configure CA and CRL URLs
vault write pki/config/urls \
    issuing_certificates="http://172.16.0.4:8200/v1/pki/ca" \
    crl_distribution_points="http://172.16.0.4:8200/v1/pki/crl"
```

## Step 2: Integrate with ADCS Root CA (Option B - Enterprise)

If you have Microsoft ADCS or another Root CA:

```bash
# Generate intermediate CSR
vault write -field=csr pki/intermediate/generate/internal \
    common_name="Lab Intermediate CA" \
    issuer_name="lab-intermediate" \
    > pki_intermediate.csr

# Submit CSR to your ADCS/Root CA and get the signed certificate
# Then import the signed certificate:
vault write pki/intermediate/set-signed \
    certificate=@signed_intermediate.crt
```

## Step 3: Create PKI Role for Kubernetes

Create a role that cert-manager will use to issue certificates:

```bash
# Create role for lab.mxe11.nl domain
vault write pki/roles/lab-mxe11-nl \
    allowed_domains="lab.mxe11.nl,apps.lab.mxe11.nl" \
    allow_subdomains=true \
    allow_glob_domains=true \
    allow_wildcard_certificates=true \
    max_ttl="720h" \
    ttl="720h"
```

## Step 4: Configure Kubernetes Authentication

Enable and configure Kubernetes auth method in Vault:

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth (from outside the cluster)
vault write auth/kubernetes/config \
    kubernetes_host="https://your-k8s-api:6443" \
    kubernetes_ca_cert=@/path/to/ca.crt

# Or configure from inside a pod:
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"
```

## Step 5: Create Vault Policy for cert-manager

Create a policy that allows cert-manager to sign certificates:

```bash
# Create policy file
cat > cert-manager-policy.hcl <<EOF
path "pki/sign/lab-mxe11-nl" {
  capabilities = ["create", "update"]
}

path "pki/issue/lab-mxe11-nl" {
  capabilities = ["create", "update"]
}
EOF

# Write policy to Vault
vault policy write cert-manager cert-manager-policy.hcl
```

## Step 6: Create Kubernetes Role in Vault

Bind the policy to a Kubernetes service account:

```bash
vault write auth/kubernetes/role/cert-manager \
    bound_service_account_names=cert-manager-vault-issuer \
    bound_service_account_namespaces=cert-manager \
    policies=cert-manager \
    ttl=24h
```

## Step 7: Deploy Kubernetes Resources

### Create Service Account

```bash
kubectl create serviceaccount cert-manager-vault-issuer -n cert-manager
```

### Create ClusterIssuer

Apply this configuration to your cluster:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-pki-issuer
spec:
  vault:
    server: http://172.16.0.4:8200
    path: pki/sign/lab-mxe11-nl
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        serviceAccountRef:
          name: cert-manager-vault-issuer
```

### Test Certificate Request

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-vault-cert
  namespace: default
spec:
  secretName: test-vault-cert-tls # pragma: allowlist secret
  issuerRef:
    name: vault-pki-issuer
    kind: ClusterIssuer
  commonName: test.apps.lab.mxe11.nl
  dnsNames:
    - test.apps.lab.mxe11.nl
```

## Verification

Check certificate status:

```bash
kubectl describe certificate test-vault-cert -n default
kubectl get secret test-vault-cert-tls -n default
```

Check cert-manager logs:

```bash
kubectl logs -n cert-manager -l app=cert-manager -f
```

## Switching from Let's Encrypt to Vault PKI

Once Vault PKI is working, you can switch applications from Let's Encrypt to Vault:

1. **For internal services**: Use `vault-pki-issuer` for faster issuance and no rate limits
2. **For public services**: Continue using `cloudflare-dns-issuer` (Let's Encrypt)

Update certificate issuerRef:

```yaml
# Before (Let's Encrypt)
issuerRef:
  name: cloudflare-dns-issuer
  kind: ClusterIssuer

# After (Vault PKI)
issuerRef:
  name: vault-pki-issuer
  kind: ClusterIssuer
```

## Troubleshooting

### Certificate Not Being Issued

1. Check ClusterIssuer status:
   ```bash
   kubectl get clusterissuer vault-pki-issuer -o yaml
   ```

2. Check cert-manager logs for authentication errors:
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager | grep -i vault
   ```

3. Verify Kubernetes auth configuration in Vault:
   ```bash
   vault read auth/kubernetes/role/cert-manager
   ```

### Vault Authentication Failed

1. Check service account token:
   ```bash
   kubectl get sa cert-manager-vault-issuer -n cert-manager -o yaml
   ```

2. Verify Vault can reach Kubernetes API
3. Check Vault logs for authentication errors

## Integration with ADCS

For Microsoft Active Directory Certificate Services integration:

1. Use ADCS to sign Vault's intermediate CA certificate
2. Configure Vault with the signed intermediate certificate
3. All certificates issued through Vault will chain to your ADCS root
4. Benefits:
   - Centralized enterprise PKI management
   - Compliance with corporate certificate policies
   - Integration with Windows domain trust

## Next Steps

- Configure automatic certificate renewal (cert-manager handles this automatically)
- Set up monitoring for certificate expiration
- Create different PKI roles for different certificate types (client certs, server certs, etc.)
- Consider enabling Vault audit logging for certificate issuance tracking
