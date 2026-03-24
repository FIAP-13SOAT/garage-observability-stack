resource "datadog_dashboard_json" "garage_operations" {
  dashboard = <<-JSON
    {
      "title": "Garage - Operacoes de Ordens de Servico",
      "description": "Dashboard operacional da aplicacao Garage. Exibe metricas de volume, performance, erros, latencia, status de ordens de servico, consumo de recursos Kubernetes e uptime.",
      "layout_type": "ordered",
      "template_variables": [
        { "name": "env", "prefix": "env", "default": "${local.environment}" },
        { "name": "service", "prefix": "service", "default": "garage" }
      ],
      "widgets": [
        {
          "definition": {
            "type": "timeseries",
            "title": "Volume Diario de OS Criadas",
            "requests": [{
              "q": "sum:garage.service_order.created.count{service:garage,$env}.as_count().rollup(sum, 86400)",
              "display_type": "bars",
              "style": { "palette": "dog_classic", "line_type": "solid", "line_width": "normal" }
            }],
            "yaxis": { "label": "Ordens Criadas", "scale": "linear", "include_zero": true },
            "time": { "live_span": "1w" }
          }
        },
        {
          "definition": {
            "type": "group",
            "title": "Tempo Medio por Fase",
            "layout_type": "ordered",
            "widgets": [
              {
                "definition": {
                  "type": "query_value", "title": "Diagnostico (IN_DIAGNOSIS)",
                  "requests": [{ "q": "avg:garage.service_order.processing.duration.avg{service:garage,$env,operation:start_diagnosis}", "aggregator": "avg" }],
                  "autoscale": true, "precision": 0, "time": { "live_span": "1d" }
                }
              },
              {
                "definition": {
                  "type": "query_value", "title": "Execucao (IN_PROGRESS)",
                  "requests": [{ "q": "avg:garage.service_order.processing.duration.avg{service:garage,$env,operation:complete}", "aggregator": "avg" }],
                  "autoscale": true, "precision": 0, "time": { "live_span": "1d" }
                }
              },
              {
                "definition": {
                  "type": "query_value", "title": "Finalizacao (COMPLETED)",
                  "requests": [{ "q": "avg:garage.service_order.processing.duration.avg{service:garage,$env,operation:deliver}", "aggregator": "avg" }],
                  "autoscale": true, "precision": 0, "time": { "live_span": "1d" }
                }
              }
            ]
          }
        },
        {
          "definition": {
            "type": "toplist",
            "title": "Contagem de Erros por Operacao",
            "requests": [{ "q": "top(sum:garage.service_order.error.count{service:garage,$env} by {operation}.as_count(), 10, 'sum', 'desc')", "style": { "palette": "warm" } }],
            "time": { "live_span": "1d" }
          }
        },
        {
          "definition": {
            "type": "timeseries",
            "title": "Latencia p50/p90/p99 das APIs REST",
            "requests": [
              { "q": "p50:http.server.requests.duration{service:garage,$env}", "display_type": "line", "style": { "palette": "cool", "line_type": "solid", "line_width": "normal" }, "metadata": [{ "expression": "p50:http.server.requests.duration{service:garage,$env}", "alias_name": "p50" }] },
              { "q": "p90:http.server.requests.duration{service:garage,$env}", "display_type": "line", "style": { "palette": "orange", "line_type": "solid", "line_width": "normal" }, "metadata": [{ "expression": "p90:http.server.requests.duration{service:garage,$env}", "alias_name": "p90" }] },
              { "q": "p99:http.server.requests.duration{service:garage,$env}", "display_type": "line", "style": { "palette": "warm", "line_type": "solid", "line_width": "normal" }, "metadata": [{ "expression": "p99:http.server.requests.duration{service:garage,$env}", "alias_name": "p99" }] }
            ],
            "yaxis": { "label": "Latencia (ms)", "scale": "linear", "include_zero": true },
            "time": { "live_span": "4h" }
          }
        },
        {
          "definition": {
            "type": "toplist",
            "title": "Ordens Ativas por Status",
            "requests": [{ "q": "top(avg:garage.service_order.active.count{service:garage,$env} by {status}, 10, 'mean', 'desc')", "style": { "palette": "dog_classic" } }],
            "time": { "live_span": "1h" }
          }
        },
        {
          "definition": {
            "type": "timeseries",
            "title": "Consumo CPU/Memoria dos Pods",
            "requests": [
              { "q": "avg:kubernetes.cpu.usage.total{kube_deployment:garage,$env} by {pod_name}", "display_type": "line", "style": { "palette": "cool", "line_type": "solid", "line_width": "normal" }, "metadata": [{ "expression": "avg:kubernetes.cpu.usage.total{kube_deployment:garage,$env} by {pod_name}", "alias_name": "CPU" }] },
              { "q": "avg:kubernetes.memory.usage{kube_deployment:garage,$env} by {pod_name}", "display_type": "line", "style": { "palette": "warm", "line_type": "solid", "line_width": "normal" }, "metadata": [{ "expression": "avg:kubernetes.memory.usage{kube_deployment:garage,$env} by {pod_name}", "alias_name": "Memory" }] }
            ],
            "yaxis": { "scale": "linear", "include_zero": true },
            "time": { "live_span": "4h" }
          }
        },
        {
          "definition": {
            "type": "group",
            "title": "Uptime Percentual",
            "layout_type": "ordered",
            "widgets": [
              {
                "definition": {
                  "type": "query_value", "title": "Uptime 24h",
                  "requests": [{ "q": "(1 - avg:garage.health.downtime{service:garage,$env}.rollup(avg, 86400)) * 100", "aggregator": "last", "conditional_formats": [{ "comparator": ">=", "value": 99.9, "palette": "white_on_green" }, { "comparator": ">=", "value": 99, "palette": "white_on_yellow" }, { "comparator": "<", "value": 99, "palette": "white_on_red" }] }],
                  "autoscale": false, "custom_unit": "%", "precision": 2, "time": { "live_span": "1d" }
                }
              },
              {
                "definition": {
                  "type": "query_value", "title": "Uptime 7d",
                  "requests": [{ "q": "(1 - avg:garage.health.downtime{service:garage,$env}.rollup(avg, 604800)) * 100", "aggregator": "last", "conditional_formats": [{ "comparator": ">=", "value": 99.9, "palette": "white_on_green" }, { "comparator": ">=", "value": 99, "palette": "white_on_yellow" }, { "comparator": "<", "value": 99, "palette": "white_on_red" }] }],
                  "autoscale": false, "custom_unit": "%", "precision": 2, "time": { "live_span": "1w" }
                }
              }
            ]
          }
        }
      ]
    }
    JSON
}
