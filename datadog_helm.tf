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

          dogstatsd:
            port: 8125
            nonLocalTraffic: true
            useHostPort: true

          logs:
            enabled: true
            containerCollectAll: true

          processAgent:
            enabled: true
            processCollection: false

          containerLifecycle:
            enabled: true

          orchestratorExplorer:
            enabled: true

          containerImage:
            enabled: true

          remoteConfiguration:
            enabled: false

          kubelet:
            enabled: true
            tlsVerify: false

          tags:
            - "env:${local.environment}"
            - "service:garage"

        clusterAgent:
          enabled: true
          replicas: 1
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
          useHostNetwork: true
          containers:
            agent:
              env:
                - name: DD_KUBELET_TLS_VERIFY
                  value: "false"
                - name: DD_KUBELET_USE_API_SERVER
                  value: "true"
                - name: DD_KUBELET_CLIENT_CA
                  value: ""
              resources:
                requests:
                  cpu: 200m
                  memory: 512Mi
                limits:
                  cpu: 500m
                  memory: 1024Mi
            traceAgent:
              enabled: true
    YAML
  ]

  depends_on = [
    kubernetes_secret.datadog_api_key
  ]
}
