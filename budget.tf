resource "aws_budgets_budget" "service" {
  for_each = var.service_budgets

  name         = "budget-${each.key}-${var.service_budgets[each.key].time_unit}"
  budget_type  = "COST"
  limit_amount = var.service_budgets[each.key].limit_amount
  limit_unit   = var.service_budgets[each.key].limit_unit
  time_unit    = var.service_budgets[each.key].time_unit

  cost_filter {
    name   = "Service"
    values = [var.aws_service_shorthand_map[each.key]]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = var.service_budgets[each.key].threshold
    threshold_type      = var.service_budgets[each.key].threshold_type
    notification_type   = var.service_budgets[each.key].notification_type

    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }
}

locals {
  ri_services = var.monitor_ri_utilization ? var.ri_utilization_services : []
}

resource "aws_budgets_budget" "ri_utilization" {
  for_each = toset(local.ri_services)

  name         = "budget-RI-${var.aws_service_shorthand_map[each.key]}"
  budget_type  = "RI_UTILIZATION"
  limit_amount = "100.0"
  limit_unit   = "PERCENTAGE"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      var.aws_service_shorthand_map[each.key]
    ]
  }

  cost_types {
    include_credit             = false
    include_discount           = false
    include_other_subscription = false
    include_recurring          = false
    include_refund             = false
    include_subscription       = true
    include_support            = false
    include_tax                = false
    include_upfront            = false
    use_blended                = false
  }

  notification {
    notification_type         = "ACTUAL"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    comparison_operator       = "LESS_THAN"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }
}

resource "aws_budgets_budget" "sp_utilization" {
  count = var.monitor_sp_utilization ? 1 : 0

  name         = "budget-SavingsPlan-UTILIZATION"
  budget_type  = "SAVINGS_PLANS_UTILIZATION"
  limit_amount = "100.0"
  limit_unit   = "PERCENTAGE"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = false
    include_discount           = false
    include_other_subscription = false
    include_recurring          = false
    include_refund             = false
    include_subscription       = true
    include_support            = false
    include_tax                = false
    include_upfront            = false
    use_blended                = false
  }

  notification {
    notification_type         = "ACTUAL"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    comparison_operator       = "LESS_THAN"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }
}
