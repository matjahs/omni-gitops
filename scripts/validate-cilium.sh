#!/bin/bash
# Validation script for Cilium + ArgoCD + Talos setup
# This script verifies that Cilium is correctly configured and managed by ArgoCD

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Cilium + ArgoCD Configuration Validator"
echo "=========================================="
echo ""

# Check if required tools are installed
echo "Checking required tools..."
for cmd in kubectl helm cilium argocd; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}✗${NC} $cmd not found. Please install it first."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $cmd found"
done
echo ""

# 1. Verify Cilium installation
echo "1. Checking Cilium installation..."
if kubectl get daemonset -n kube-system cilium &> /dev/null; then
    echo -e "${GREEN}✓${NC} Cilium DaemonSet exists in kube-system namespace"
else
    echo -e "${RED}✗${NC} Cilium DaemonSet not found in kube-system namespace"
    exit 1
fi

# Check Cilium pods
CILIUM_READY=$(kubectl get pods -n kube-system -l k8s-app=cilium -o json | jq -r '.items | length')
CILIUM_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=cilium -o json | jq -r '[.items[] | select(.status.phase=="Running")] | length')
echo -e "   Cilium pods: ${CILIUM_RUNNING}/${CILIUM_READY} running"
if [ "$CILIUM_READY" -eq "$CILIUM_RUNNING" ]; then
    echo -e "${GREEN}✓${NC} All Cilium pods are running"
else
    echo -e "${YELLOW}⚠${NC} Some Cilium pods are not running"
fi
echo ""

# 2. Verify Helm release
echo "2. Checking Helm release..."
if helm list -n kube-system | grep -q cilium; then
    HELM_VERSION=$(helm list -n kube-system -o json | jq -r '.[] | select(.name=="cilium") | .chart')
    echo -e "${GREEN}✓${NC} Cilium Helm release found: $HELM_VERSION"
else
    echo -e "${RED}✗${NC} Cilium Helm release not found"
    exit 1
fi
echo ""

# 3. Verify kube-proxy is disabled
echo "3. Checking kube-proxy status..."
KUBE_PROXY_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy -o json | jq -r '.items | length')
if [ "$KUBE_PROXY_PODS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} kube-proxy is disabled (no pods found)"
else
    echo -e "${RED}✗${NC} kube-proxy is running ($KUBE_PROXY_PODS pods found)"
fi

# Verify Cilium has kube-proxy replacement enabled
KUBE_PROXY_REPLACEMENT=$(cilium config view | grep "kube-proxy-replacement" | awk '{print $2}')
if [ "$KUBE_PROXY_REPLACEMENT" = "true" ]; then
    echo -e "${GREEN}✓${NC} Cilium kube-proxy replacement is enabled"
else
    echo -e "${RED}✗${NC} Cilium kube-proxy replacement is disabled"
fi
echo ""

# 4. Check Cilium configuration against expected values
echo "4. Verifying Cilium configuration..."

# Check critical settings
declare -A EXPECTED_CONFIG=(
    ["ipam"]="kubernetes"
    ["kube-proxy-replacement"]="true"
    ["k8s-service-host"]="localhost"
    ["k8s-service-port"]="7445"
    ["enable-hubble"]="true"
    ["enable-bgp-control-plane"]="true"
    ["enable-gateway-api"]="true"
    ["routing-mode"]="tunnel"
    ["tunnel-protocol"]="vxlan"
)

ALL_CONFIG_OK=true
for key in "${!EXPECTED_CONFIG[@]}"; do
    ACTUAL_VALUE=$(cilium config view | grep "^${key}" | awk '{print $2}')
    EXPECTED_VALUE="${EXPECTED_CONFIG[$key]}"

    if [ "$ACTUAL_VALUE" = "$EXPECTED_VALUE" ]; then
        echo -e "${GREEN}✓${NC} ${key}: ${ACTUAL_VALUE}"
    else
        echo -e "${RED}✗${NC} ${key}: expected '${EXPECTED_VALUE}', got '${ACTUAL_VALUE}'"
        ALL_CONFIG_OK=false
    fi
done
echo ""

# 5. Check Hubble components
echo "5. Checking Hubble components..."
if kubectl get deployment -n kube-system hubble-relay &> /dev/null; then
    echo -e "${GREEN}✓${NC} Hubble Relay deployment exists"
else
    echo -e "${YELLOW}⚠${NC} Hubble Relay deployment not found"
fi

if kubectl get deployment -n kube-system hubble-ui &> /dev/null; then
    echo -e "${GREEN}✓${NC} Hubble UI deployment exists"
else
    echo -e "${YELLOW}⚠${NC} Hubble UI deployment not found"
fi
echo ""

# 6. Verify ArgoCD application
echo "6. Checking ArgoCD application..."
if kubectl get application -n argocd cilium-helm-release &> /dev/null; then
    echo -e "${GREEN}✓${NC} ArgoCD Application 'cilium-helm-release' exists"

    # Check sync status
    SYNC_STATUS=$(kubectl get application -n argocd cilium-helm-release -o jsonpath='{.status.sync.status}')
    HEALTH_STATUS=$(kubectl get application -n argocd cilium-helm-release -o jsonpath='{.status.health.status}')

    echo "   Sync Status: $SYNC_STATUS"
    echo "   Health Status: $HEALTH_STATUS"

    if [ "$SYNC_STATUS" = "Synced" ]; then
        echo -e "${GREEN}✓${NC} Application is synced"
    else
        echo -e "${YELLOW}⚠${NC} Application is not synced"
    fi

    if [ "$HEALTH_STATUS" = "Healthy" ]; then
        echo -e "${GREEN}✓${NC} Application is healthy"
    else
        echo -e "${YELLOW}⚠${NC} Application is not healthy"
    fi
else
    echo -e "${YELLOW}⚠${NC} ArgoCD Application 'cilium-helm-release' not found"
    echo "   (Application may not be deployed yet)"
fi
echo ""

# 7. Verify ArgoCD resource exclusions
echo "7. Checking ArgoCD resource exclusions..."
if kubectl get configmap -n argocd argocd-cm &> /dev/null; then
    if kubectl get configmap -n argocd argocd-cm -o yaml | grep -q "CiliumIdentity"; then
        echo -e "${GREEN}✓${NC} CiliumIdentity resource exclusion configured"
    else
        echo -e "${RED}✗${NC} CiliumIdentity resource exclusion not found"
        echo "   Add this to argocd-cm ConfigMap:"
        echo "   resource.exclusions: |"
        echo "     - apiGroups:"
        echo "       - cilium.io"
        echo "       kinds:"
        echo "       - CiliumIdentity"
    fi
else
    echo -e "${YELLOW}⚠${NC} ArgoCD ConfigMap not found"
fi
echo ""

# 8. Check Cilium connectivity
echo "8. Testing Cilium connectivity..."
echo "   Running: cilium connectivity test --test pod-to-pod --test pod-to-service"
if cilium connectivity test --test pod-to-pod --test pod-to-service --request-timeout 30s &> /dev/null; then
    echo -e "${GREEN}✓${NC} Cilium connectivity tests passed"
else
    echo -e "${YELLOW}⚠${NC} Cilium connectivity tests failed or timed out"
    echo "   Run 'cilium connectivity test' for detailed results"
fi
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
if [ "$ALL_CONFIG_OK" = true ] && [ "$CILIUM_READY" -eq "$CILIUM_RUNNING" ] && [ "$KUBE_PROXY_PODS" -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Verify Hubble UI is accessible via ingress"
    echo "  2. Check ArgoCD application sync status"
    echo "  3. Monitor for any policy violations in Hubble"
    exit 0
else
    echo -e "${YELLOW}⚠ Some checks failed or showed warnings${NC}"
    echo ""
    echo "Review the output above and fix any issues."
    exit 1
fi
