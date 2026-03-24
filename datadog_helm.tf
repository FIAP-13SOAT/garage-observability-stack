resource "kubernetes_namespace" "datadog" {
  metadata {
    name = "datadog"
  }
}

resource "kubernetes_secret" "datadog_api_key" {
  metadata {
    name      = "datadog-api-key"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }
}

resource "helm_release" "datadog_agent" {
  name       = "datadog-agent"
  chart      = "./charts/datadog"
  namespace  = kubernetes_namespace.datadog.metadata[0].name

  values = [<<-YAML
        datadog:
          apiKeyExistingSecret: datadog-api-key
          site: us5.datadoghq.com

          apm:
            portEnabled: true
            port: 8126

          dogstatsd:
            port: 8125
            nonLocalTraffic: true
            useHostPort: true

          logs:
            enabled: true
            containerCollectAll: false
            containerCollectUsingFiles: true

          processAgent:
            enabled: true
            processCollection: false

          kubelet:
            enabled: true

          tags:
            - "env:${local.environment}"
            - "service:garage"

        agents:
          tolerations:
            - operator: Exists
    YAML
  ]

  depends_on = [
    kubernetes_secret.datadog_api_key
  ]
}
