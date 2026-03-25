resource "datadog_dashboard_json" "garage_operations" {
  dashboard = file("${path.module}/datadog/dashboard/garage-operations.json")
}
