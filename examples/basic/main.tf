
module "example" {
  source = "../.."

  datadog_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-1we4dj"

  # Anomaly detection vars
  anomaly_total_impact_percentage_threshold = 5
  anomaly_total_impact_absolute_threshold   = 250

  # budget vars
  monitor_ri_utilization = true
  monitor_sp_utilization = true

  service_budgets = {
    "ec2" = {
      time_unit         = "DAILY"
      limit_amount      = "100" # Adjust this value based on your budget
      limit_unit        = "USD"
      threshold         = 90 # Notify when spending exceeds 90% of the budget
      threshold_type    = "PERCENTAGE"
      notification_type = "ACTUAL"
    }
  }

  # cost and usage
  enable_cur_collection          = false
  enable_datadog_cost_management = true

}
