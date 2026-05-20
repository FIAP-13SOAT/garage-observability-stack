output "datadog_agent_status" {
  description = "Status do Helm release do Datadog Agent"
  value       = helm_release.datadog_agent.status
}
