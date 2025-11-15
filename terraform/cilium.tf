// see https://www.talos.dev/v1.7/kubernetes-guides/network/deploying-cilium/#method-4-helm-manifests-inline-install
// see https://docs.cilium.io/en/stable/network/servicemesh/ingress/
// see https://docs.cilium.io/en/stable/gettingstarted/hubble_setup/
// see https://docs.cilium.io/en/stable/gettingstarted/hubble/
// see https://docs.cilium.io/en/stable/helm-reference/#helm-reference
// see https://github.com/cilium/cilium/releases
// see https://github.com/cilium/cilium/tree/v1.16.0/install/kubernetes/cilium
// see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template
data "helm_template" "cilium" {
  namespace  = "kube-system"
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  # renovate: datasource=helm depName=cilium registryUrl=https://helm.cilium.io
  version      = "1.18.2"
  kube_version = var.kubernetes_version
  api_versions = []

  set = [
    { name = "ipam.mode", value = "kubernetes" },
    { name = "securityContext.capabilities.ciliumAgent", value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" },
    { name = "securityContext.capabilities.cleanCiliumState", value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" },
    { name = "cgroup.autoMount.enabled", value = "false" },
    { name = "cgroup.hostRoot", value = "/sys/fs/cgroup" },
    { name = "k8sServiceHost", value = "localhost" },
    { name = "k8sServicePort", value = "7445" },
    { name = "kubeProxyReplacement", value = "true" },
    { name = "l2announcements.enabled", value = "true" },
    { name = "devices", value = "{eth0}" },
    { name = "ingressController.enabled", value = "true" },
    { name = "ingressController.default", value = "true" },
    { name = "ingressController.loadbalancerMode", value = "shared" },
    { name = "ingressController.enforceHttps", value = "false" },
    { name = "envoy.enabled", value = "true" },
    { name = "hubble.relay.enabled", value = "true" },
    { name = "hubble.ui.enabled", value = "true" },
  ]
}
