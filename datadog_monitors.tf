# --- Service Order Error Rate ---
resource "datadog_monitor" "service_order_error_rate" {
    name    = "[Garage] Service Order Error Rate - ${local.environment}"
    type    = "metric alert"
    query   = "sum(last_5m):sum:garage.service_order.error.count{service:garage,env:${local.environment}} by {operation}.as_count() / sum:garage.service_order.processing.duration.count{service:garage,env:${local.environment}} by {operation}.as_count() * 100 > 15"
    message = <<-EOT
        {{#is_alert}}
        CRITICAL: Taxa de erros em operacoes de Ordem de Servico acima de 15%.
        {{/is_alert}}
        {{#is_warning}}
        WARNING: Taxa de erros em operacoes de Ordem de Servico acima de 5%.
        {{/is_warning}}

        Servico: {{service}}
        Ambiente: ${local.environment}
        Operacao afetada: {{operation.name}}

        @slack-garage-alerts
    EOT

    monitor_thresholds {
        warning  = 5
        critical = 15
    }

    notify_no_data      = false
    evaluation_delay    = 60
    include_tags        = true
    notify_audit        = false
    require_full_window = false
    new_group_delay     = 60

    tags = ["env:${local.environment}", "service:garage", "team:garage"]
}

# --- Health Check ---
resource "datadog_monitor" "health_check" {
    name    = "[Garage] Health Check DOWN - ${local.environment}"
    type    = "service check"
    query   = "\"http.can_connect\".over(\"instance:garage-health,url:http://localhost:8080/actuator/health\").by(\"host\",\"instance\").last(2).count_by_status()"
    message = <<-EOT
        {{#is_alert}}
        CRITICAL: O healthcheck da aplicacao Garage esta retornando DOWN ha mais de 2 minutos consecutivos.
        {{/is_alert}}

        Servico: {{service}}
        Ambiente: ${local.environment}

        O endpoint /actuator/health esta indisponivel ou retornando status DOWN.

        @slack-garage-alerts @pagerduty-garage
    EOT

    monitor_thresholds {
        critical = 2
    }

    notify_no_data    = true
    no_data_timeframe = 5
    evaluation_delay  = 60
    include_tags      = true
    notify_audit      = false

    tags = ["env:${local.environment}", "service:garage", "team:garage"]
}

# --- API Latency P95 ---
resource "datadog_monitor" "api_latency_p95" {
    name    = "[Garage] API Latency P95 High - ${local.environment}"
    type    = "metric alert"
    query   = "percentile(last_5m):p95:http.server.requests.duration{service:garage,env:${local.environment}} by {uri} > 2000"
    message = <<-EOT
        {{#is_alert}}
        CRITICAL: A latencia P95 das APIs ultrapassou 2000ms nos ultimos 5 minutos.
        {{/is_alert}}
        {{#is_warning}}
        WARNING: A latencia P95 das APIs ultrapassou 1000ms nos ultimos 5 minutos.
        {{/is_warning}}

        Servico: {{service}}
        Ambiente: ${local.environment}
        Operacao afetada: {{uri.name}}

        @slack-garage-alerts
    EOT

    monitor_thresholds {
        warning  = 1000
        critical = 2000
    }

    notify_no_data      = false
    evaluation_delay    = 60
    include_tags        = true
    notify_audit        = false
    require_full_window = false
    new_group_delay     = 60

    tags = ["env:${local.environment}", "service:garage", "team:garage"]
}

# --- Memory Usage ---
resource "datadog_monitor" "memory_usage" {
    name    = "[Garage] Memory Usage High - ${local.environment}"
    type    = "metric alert"
    query   = "avg(last_5m):avg:kubernetes.memory.usage{service:garage,env:${local.environment}} by {pod_name} / 1073741824 * 100 > 95"
    message = <<-EOT
        {{#is_alert}}
        CRITICAL: Consumo de memoria de um pod ultrapassou 95% do limite (1Gi).
        {{/is_alert}}
        {{#is_warning}}
        WARNING: Consumo de memoria de um pod ultrapassou 80% do limite (1Gi).
        {{/is_warning}}

        Servico: {{service}}
        Ambiente: ${local.environment}
        Pod: {{pod_name.name}}

        @slack-garage-alerts
    EOT

    monitor_thresholds {
        warning  = 80
        critical = 95
    }

    notify_no_data      = false
    evaluation_delay    = 60
    include_tags        = true
    notify_audit        = false
    require_full_window = false
    new_group_delay     = 60

    tags = ["env:${local.environment}", "service:garage", "team:garage"]
}

# --- CPU Usage ---
resource "datadog_monitor" "cpu_usage" {
    name    = "[Garage] CPU Usage High - ${local.environment}"
    type    = "metric alert"
    query   = "avg(last_5m):avg:kubernetes.cpu.usage.total{service:garage,env:${local.environment}} by {pod_name} / 500000000 * 100 > 95"
    message = <<-EOT
        {{#is_alert}}
        CRITICAL: Consumo de CPU de um pod ultrapassou 95% do limite (500m).
        {{/is_alert}}
        {{#is_warning}}
        WARNING: Consumo de CPU de um pod ultrapassou 80% do limite (500m).
        {{/is_warning}}

        Servico: {{service}}
        Ambiente: ${local.environment}
        Pod: {{pod_name.name}}

        @slack-garage-alerts
    EOT

    monitor_thresholds {
        warning  = 80
        critical = 95
    }

    notify_no_data      = false
    evaluation_delay    = 60
    include_tags        = true
    notify_audit        = false
    require_full_window = false
    new_group_delay     = 60

    tags = ["env:${local.environment}", "service:garage", "team:garage"]
}
