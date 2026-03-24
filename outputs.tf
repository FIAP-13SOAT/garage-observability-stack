output "datadog_agent_status" {
  description = "Status do Helm release do Datadog Agent"
  value       = helm_release.datadog_agent.status
}

output "datadog_monitor_ids" {
  description = "IDs dos monitores criados no Datadog"
  value = {
    service_order_error_rate = datadog_monitor.service_order_error_rate.id
    health_check             = datadog_monitor.health_check.id
    api_latency_p95          = datadog_monitor.api_latency_p95.id
    memory_usage             = datadog_monitor.memory_usage.id
    cpu_usage                = datadog_monitor.cpu_usage.id
  }
}

output "datadog_dashboard_url" {
  description = "URL do dashboard no Datadog"
  value       = datadog_dashboard_json.garage_operations.url
}
