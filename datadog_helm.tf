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
  name      = "datadog-agent"
  chart     = "./charts/datadog"
  namespace = kubernetes_namespace.datadog.metadata[0].name
  timeout   = 600
  wait      = false

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

          containerExclude: "name:datadog-agent"

          tags:
            - "env:${local.environment}"
            - "service:garage"

        clusterAgent:
          enabled: true
          metricsProvider:
            enabled: false
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 200m
              memory: 512Mi

        agents:
          tolerations:
            - operator: Exists
          containers:
            agent:
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  cpu: 200m
                  memory: 512Mi
    YAML
  ]

  depends_on = [
    kubernetes_secret.datadog_api_key
  ]
}
