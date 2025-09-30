# Troubleshooting Guide

## Common Issues

### Bootstrap Issues

#### ArgoCD Installation Fails
**Symptoms:**
```bash
kubectl apply -k clusters/cluster1/
# Error: unable to apply manifests
```

**Diagnosis:**
```bash
# Check cluster connectivity
kubectl cluster-info

# Check available resources
kubectl describe nodes

# Check for existing ArgoCD installation
kubectl get ns argocd
```

**Solutions:**
```bash
# Clean up partial installation
kubectl delete namespace argocd --force --grace-period=0

# Retry bootstrap
./bootstrap.sh

# Manual installation if needed
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### Bootstrap Script Hangs
**Symptoms:**
- Script stops at "Waiting for ArgoCD server to be ready..."
- Timeout after 300 seconds

**Diagnosis:**
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check pod logs
kubectl logs -n argocd deployment/argocd-server

# Check resource constraints
kubectl describe pods -n argocd
```

**Solutions:**
```bash
# Increase timeout and retry
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Check if pods are pending due to resources
kubectl get pods -n argocd -o wide

# Scale down replicas temporarily
kubectl scale deployment argocd-server --replicas=1 -n argocd
```

### ArgoCD Issues

#### Applications Stuck in "Unknown" State
**Symptoms:**
- Applications show "Unknown" health status
- Sync status shows "Unknown"

**Diagnosis:**
```bash
# Check application details
kubectl describe application <app-name> -n argocd

# Check ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check repository access
argocd repo list
```

**Solutions:**
```bash
# Refresh application
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"refresh":{}}}'

# Hard refresh (ignore cache)
argocd app get <app-name> --hard-refresh

# Check repository credentials
argocd repo get https://github.com/matjahs/omni-gitops
```

#### Applications Not Auto-Syncing
**Symptoms:**
- Changes committed to Git but not appearing in cluster
- Manual sync works but automatic sync doesn't

**Diagnosis:**
```bash
# Check sync policy
kubectl get application <app-name> -n argocd -o yaml | grep -A 10 syncPolicy

# Check ArgoCD configuration
kubectl get configmap argocd-cm -n argocd -o yaml

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Solutions:**
```yaml
# Ensure sync policy is configured
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### ArgoCD UI Not Accessible
**Symptoms:**
- Cannot access https://cd.apps.lab.mxe11.nl
- Connection timeout or certificate errors

**Diagnosis:**
```bash
# Check ArgoCD server pod
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check ingress configuration
kubectl get ingress -n argocd

# Check Traefik logs
kubectl logs -n traefik-system deployment/traefik

# Test local port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Solutions:**
```bash
# Restart ArgoCD server
kubectl rollout restart deployment/argocd-server -n argocd

# Check DNS resolution
nslookup cd.apps.lab.mxe11.nl

# Verify certificate
openssl s_client -connect cd.apps.lab.mxe11.nl:443
```

### Traefik Issues

#### SSL Certificate Issues
**Symptoms:**
- Browser shows certificate warnings
- Let's Encrypt challenges failing

**Diagnosis:**
```bash
# Check certificate status
kubectl get certificates --all-namespaces

# Check cert-manager logs (if using cert-manager)
kubectl logs -n cert-manager deployment/cert-manager

# Check Traefik ACME logs
kubectl logs -n traefik-system deployment/traefik | grep -i acme

# Check ingress annotations
kubectl describe ingress <ingress-name>
```

**Solutions:**
```bash
# Delete and recreate certificate
kubectl delete certificate <cert-name>

# Check ACME configuration in Traefik
kubectl get configmap traefik-config -n traefik-system -o yaml

# Verify domain DNS points to correct IP
dig cd.apps.lab.mxe11.nl
```

#### Ingress Not Working
**Symptoms:**
- 404 errors for applications
- Traefik dashboard not accessible

**Diagnosis:**
```bash
# Check Traefik pods
kubectl get pods -n traefik-system

# Check Traefik service
kubectl get svc -n traefik-system

# Check ingress resources
kubectl get ingress --all-namespaces

# Check Traefik configuration
kubectl logs -n traefik-system deployment/traefik
```

**Solutions:**
```bash
# Restart Traefik
kubectl rollout restart deployment/traefik -n traefik-system

# Check service endpoints
kubectl get endpoints -n traefik-system

# Verify ingress class
kubectl get ingressclass
```

### MetalLB Issues

#### LoadBalancer Services Stuck Pending
**Symptoms:**
- Services of type LoadBalancer show "Pending" external IP
- No IP assigned from pool

**Diagnosis:**
```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check IP address pools
kubectl get ipaddresspool -n metallb-system

# Check L2 advertisements
kubectl get l2advertisement -n metallb-system

# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb
```

**Solutions:**
```bash
# Restart MetalLB controller
kubectl rollout restart deployment/controller -n metallb-system

# Check IP pool configuration
kubectl describe ipaddresspool default-pool -n metallb-system

# Verify network connectivity
ping 172.16.20.100  # Test an IP from the pool
```

#### IP Address Conflicts
**Symptoms:**
- Services get IP but are not reachable
- Network connectivity issues

**Diagnosis:**
```bash
# Check for IP conflicts on network
nmap -sn 172.16.20.0/24

# Check ARP table
arp -a | grep 172.16.20

# Check MetalLB speaker logs
kubectl logs -n metallb-system -l component=speaker
```

**Solutions:**
```bash
# Update IP pool to avoid conflicts
kubectl edit ipaddresspool default-pool -n metallb-system

# Clear ARP cache
sudo ip neigh flush all

# Restart network components
kubectl rollout restart daemonset/speaker -n metallb-system
```

### Metrics Server Issues

#### kubectl top Commands Fail
**Symptoms:**
```bash
kubectl top nodes
# Error: metrics not available
```

**Diagnosis:**
```bash
# Check metrics-server pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Check metrics-server logs
kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server

# Check API service
kubectl get apiservice v1beta1.metrics.k8s.io

# Test metrics endpoint
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

**Solutions:**
```bash
# Restart metrics-server
kubectl rollout restart deployment/metrics-server -n kube-system

# Check kubelet metrics endpoint
kubectl get --raw "/api/v1/nodes/<node-name>/proxy/metrics"

# Verify TLS configuration
kubectl describe deployment metrics-server -n kube-system
```

### Network Issues

#### Pod-to-Pod Communication Fails
**Symptoms:**
- Applications cannot reach other services
- DNS resolution issues

**Diagnosis:**
```bash
# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium status
kubectl exec -n kube-system ds/cilium -- cilium status

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# Check network policies
kubectl get networkpolicies --all-namespaces
```

**Solutions:**
```bash
# Restart Cilium
kubectl rollout restart daemonset/cilium -n kube-system

# Check Cilium configuration
kubectl get configmap cilium-config -n kube-system -o yaml

# Test connectivity
kubectl exec -it <pod-name> -- ping <target-ip>
```

#### External Traffic Not Reaching Services
**Symptoms:**
- Applications not accessible from outside cluster
- Load balancer health checks failing

**Diagnosis:**
```bash
# Check service external IPs
kubectl get svc --all-namespaces -o wide

# Check iptables rules
sudo iptables -t nat -L

# Check node port ranges
kubectl describe configmap kubeadm-config -n kube-system
```

**Solutions:**
```bash
# Check firewall rules
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # RHEL/CentOS

# Verify routing
ip route show

# Test from external host
curl -v http://<external-ip>
```

## Performance Issues

### High CPU/Memory Usage

**ArgoCD Performance:**
```bash
# Check ArgoCD resource usage
kubectl top pods -n argocd

# Increase ArgoCD resources
kubectl patch deployment argocd-server -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","resources":{"requests":{"cpu":"500m","memory":"512Mi"},"limits":{"cpu":"1000m","memory":"1Gi"}}}]}}}}'

# Scale horizontally
kubectl scale deployment argocd-server --replicas=3 -n argocd
```

**Traefik Performance:**
```bash
# Monitor Traefik metrics
kubectl port-forward -n traefik-system svc/traefik 8080:8080
# Visit http://localhost:8080/metrics

# Increase Traefik resources
kubectl patch deployment traefik -n traefik-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"traefik","resources":{"limits":{"cpu":"1000m","memory":"500Mi"}}}]}}}}'
```

### Slow Application Deployment

**ArgoCD Sync Performance:**
```bash
# Check sync waves
kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.annotations.argocd\.argoproj\.io/sync-wave}'

# Increase sync timeout
kubectl patch application <app-name> -n argocd --type merge -p '{"spec":{"syncPolicy":{"retry":{"limit":5,"backoff":{"duration":"10s","maxDuration":"5m"}}}}}'

# Enable parallel sync
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"application.instanceLabelKey":"argocd.argoproj.io/instance","server.enable.proxy.extension":"true"}}'
```

## Debugging Commands

### General Cluster Health
```bash
# Cluster overview
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces | grep -v Running

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory

# Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### ArgoCD Debugging
```bash
# Application status
argocd app list
argocd app get <app-name>
argocd app diff <app-name>

# Repository status
argocd repo list
argocd repo get https://github.com/matjahs/omni-gitops

# Cluster status
argocd cluster list
```

### Network Debugging
```bash
# Cilium debugging
kubectl exec -n kube-system ds/cilium -- cilium connectivity test
kubectl exec -n kube-system ds/cilium -- cilium monitor

# DNS debugging
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default
kubectl run test-dns --image=busybox --rm -it -- nslookup cd.apps.lab.mxe11.nl

# Service mesh debugging
kubectl get svc,endpoints --all-namespaces
```

## Recovery Procedures

### Complete Platform Recovery
```bash
# 1. Verify cluster health
kubectl get nodes

# 2. Re-run bootstrap
./bootstrap.sh

# 3. Verify applications
kubectl get applications -n argocd

# 4. Force sync if needed
argocd app sync --all
```

### Individual Application Recovery
```bash
# 1. Delete application
kubectl delete application <app-name> -n argocd

# 2. Recreate from platform manifests
kubectl apply -f applications/<app-name>.yaml

# 3. Wait for sync
argocd app wait <app-name>
```

### Configuration Rollback
```bash
# 1. Find previous working commit
git log --oneline

# 2. Rollback configuration
git revert <commit-hash>
git push origin main

# 3. Wait for ArgoCD to sync
argocd app sync <app-name>
```
