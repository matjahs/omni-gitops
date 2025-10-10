# data "helm_template" "cilium_default" {
#   name = "cilium"
#   namespace = "kube-system"

#   repository = "https://helm.cilium.io/"
#   chart      = "cilium"
#   version = "1.19.0-pre.1"
#   kube_version = var.kubernetes_version

#   set = [
#     { name = "k8sServiceHost", value = "192.168.1.193" },
#     { name = "k8sServicePort", value = "6443" },
#     { name = "ipam.mode", value = "cluster-pool" },
#     { name = "ipam.operator.clusterPoolIPv4PodCIDRList[0]", value = "10.0.0.0/8" },
#     { name = "ipam.operator.clusterPoolIPv4MaskSize", value = "24" },
#     { name = "ipv4NativeRoutingCIDR", value = "10.0.0.0/8" },
#     { name = "routingMode", value = "native" },
#     { name = "devices[0]", value = "enp1s0" },
#     { name = "autoDirectNodeRoutes", value = "true" },
#     { name = "tunnelProtocol", value = "geneve" },
#     { name = "kubeProxyReplacement", value = "true" },
#     { name = "nodePort.enabled", value = "true" },
#     { name = "nodePort.range", value = "30000,32767" },
#     { name = "nodePort.directRoutingDevice", value = "enp1s0" },
#     { name = "serviceLB.enabled", value = "true" },
#     { name = "serviceLB.ipam", value = "pool" },
#     { name = "loadBalancer.mode", value = "dsr" },
#     { name = "loadBalancer.dsrDispatch", value = "geneve" },
#     { name = "bgpControlPlane.enabled", value = "true" },
#     { name = "bgp.enabled", value = "false" },
#     { name = "upgradeCompatibility", value = "1.15" },
#     { name = "cleanState", value = "false" },
#     { name = "cleanBpfState", value = "false" },
#     { name = "nodeinit.enabled", value = "false" },
#     { name = "securityContext.capabilities.ciliumAgent[0]", value = "CHOWN" },
#     { name = "securityContext.capabilities.ciliumAgent[1]", value = "DAC_OVERRIDE" },
#     { name = "securityContext.capabilities.ciliumAgent[2]", value = "FOWNER" },
#     { name = "securityContext.capabilities.ciliumAgent[3]", value = "FSETID" },
#     { name = "securityContext.capabilities.ciliumAgent[4]", value = "IPC_LOCK" },
#     { name = "securityContext.capabilities.ciliumAgent[5]", value = "KILL" },
#     { name = "securityContext.capabilities.ciliumAgent[6]", value = "MKNOD" },
#     { name = "securityContext.capabilities.ciliumAgent[7]", value = "NET_ADMIN" },
#     { name = "securityContext.capabilities.ciliumAgent[8]", value = "NET_RAW" },
#     { name = "securityContext.capabilities.ciliumAgent[9]", value = "SETFCAP" },
#     { name = "securityContext.capabilities.ciliumAgent[10]", value = "SETFCAP" },
#     { name = "securityContext.capabilities.ciliumAgent[11]", value = "SETGID" },
#     { name = "securityContext.capabilities.ciliumAgent[12]", value = "SETPCAP" },
#     { name = "securityContext.capabilities.ciliumAgent[13]", value = "SETUID" },
#     { name = "securityContext.capabilities.ciliumAgent[14]", value = "SYS_CHROOT" },
#     { name = "securityContext.capabilities.ciliumAgent[15]", value = "SYS_RESOURCE" },
#     { name = "securityContext.capabilities.ciliumAgent[16]", value = "BPF" },
#     { name = "securityContext.capabilities.ciliumAgent[17]", value = "PERFMON" },
#     { name = "securityContext.capabilities.ciliumAgent[18]", value = "SYS_ADMIN" },
#     { name = "securityContext.capabilities.cleanCiliumState[0]", value = "NET_ADMIN" },
#     { name = "securityContext.capabilities.cleanCiliumState[1]", value = "SYS_ADMIN" },
#     { name = "securityContext.capabilities.cleanCiliumState[2]", value = "SYS_RESOURCE" },
#     { name = "hubble.enabled", value = "true" },
#     { name = "hubble.relay.enabled", value = "true" },
#     { name = "hubble.ui.enabled", value = "true" },
#     { name = "gatewayAPI.enabled", value = "true" },
#     { name = "gatewayAPI.secretsNamespace.name", value = "cilium" },
#     { name = "gatewayAPI.secretsNamespace.create", value = "false" },
#     { name = "gatewayAPI.secretsNamespace.sync", value = "true" }
#   ]
# }
