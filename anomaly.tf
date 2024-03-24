resource "aws_ce_anomaly_monitor" "cost_alerts" {
  name              = var.anomaly_cost_monitor_name
  monitor_dimension = "SERVICE"
  monitor_type      = "DIMENSIONAL"
  tags              = local.tags
}

resource "aws_ce_anomaly_subscription" "cost_alerts" {
  name             = var.anomaly_cost_subscription_name
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.cost_alerts.arn]
  tags             = local.tags

  threshold_expression {
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = [var.anomaly_total_impact_absolute_threshold]
      }
    }
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = [var.anomaly_total_impact_percentage_threshold]
      }
    }
  }

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }

  depends_on = [aws_sns_topic_policy.cost_alerts]
}
