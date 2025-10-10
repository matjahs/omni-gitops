# data "helm_template" "coredns_default" {
#   name       = "coredns"
#   namespace  = "kube-system"
#   repository = "https://coredns.github.io/helm"
#   chart      = "coredns"
#   version    = "1.11.1"
#   kube_version = var.kubernetes_version

#   set = [
#     { name = "replicaCount", value = "2" },
#     { name = "priorityClassName", value = "system-cluster-critical" },
#     { name = "serviceAccount.create", value = "true" },
#     { name = "serviceAccount.name", value = "coredns" },
#     { name = "service.type", value = "ClusterIP" },
#     { name = "service.ports[0].name", value = "dns-udp" },
#     { name = "service.ports[0].protocol", value = "UDP" },
#     { name = "service.ports[0].port", value = "53" },
#     { name = "service.ports[0].targetPort", value = "53" },
#     { name = "service.ports[1].name", value = "dns-tcp" },
#     { name = "service.ports[1].protocol", value = "TCP" },
#     { name = "service.ports[1].port", value = "53" },
#     { name = "service.ports[1].targetPort", value = "53" },
#     { name = "service.ports[2].name", value = "metrics" },
#     { name = "service.ports[2].protocol", value = "TCP" },
#     { name = "service.ports[2].port", value = "9153" },
#     { name = "service.ports[2].targetPort", value = "9153" },
#     { name = "image.repository", value = "coredns/coredns" },
#     { name = "image.tag", value = "1.11.1" },
#     { name = "resources.limits.cpu", value = "200m" },
#     { name = "resources.limits.memory", value = "170Mi" },
#     { name = "resources.requests.cpu", value = "100m" },
#     { name = "resources.requests.memory", value = "70Mi" },

#   ]
# }
