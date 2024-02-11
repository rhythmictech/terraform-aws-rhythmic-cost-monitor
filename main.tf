module "tags" {
  source  = "rhythmictech/tags/terraform"
  version = "~> 1.1.1"

  enforce_case = "UPPER"
  names        = [var.name]
  tags = merge(var.tags, {
    "ManagedBy" = "Rhythmic"
    "Type"      = "Cost"
  })
}

locals {
  # tflint-ignore: terraform_unused_declarations
  name = module.tags.name
  # tflint-ignore: terraform_unused_declarations
  tags = module.tags.tags_no_name
}
resource "aws_sns_topic" "cost_alerts" {
  name = "Rhythmic-CostAlerts"
  #trivy:ignore:avd-aws-0136
  kms_master_key_id = "alias/aws/sns"
  tags              = local.tags
}

data "aws_iam_policy_document" "cost_alerts" {
  statement {
    actions = [
      "sns:Publish"
    ]

    resources = [
      aws_sns_topic.cost_alerts.arn
    ]
  }
}

resource "aws_sns_topic_policy" "cost_alerts" {
  arn    = aws_sns_topic.cost_alerts.arn
  policy = data.aws_iam_policy_document.cost_alerts.json
}

resource "aws_ce_anomaly_monitor" "cost_alerts" {
  name              = "Rhythmic-DefaultAnomalyMonitor"
  monitor_dimension = "SERVICE"
  monitor_type      = "DIMENSIONAL"
  tags              = local.tags
}

resource "aws_ce_anomaly_subscription" "cost_alerts" {
  name             = "Rhythmic-DefaultAnomalySubscription"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.cost_alerts.arn]
  tags             = local.tags

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["10"]
    }
  }

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }

  depends_on = [aws_sns_topic_policy.cost_alerts]
}

data "aws_secretsmanager_secret" "datadog_api_key" {
  name = var.datadog_api_key_secret_arn
}

data "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id = data.aws_secretsmanager_secret.datadog_api_key.id
}

resource "aws_sns_topic_subscription" "cost_alerts" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "https"
  endpoint  = "https://app.datadoghq.com/intake/webhook/sns?api_key=${data.aws_secretsmanager_secret_version.datadog_api_key.secret_string}"
}
