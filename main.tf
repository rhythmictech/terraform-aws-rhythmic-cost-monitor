data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}


module "tags" {
  source  = "rhythmictech/tags/terraform"
  version = "~> 1.1.1"

  enforce_case = "UPPER"
  names        = ["Rhythmic-AccountMonitoring"]
  tags = merge(var.tags, {
    "team"    = "Rhythmic"
    "service" = "aws_managed_services"
    "env"     = "ops"
  })
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  tags       = module.tags.tags_no_name
  use_datadog_endpoint = var.sns_subscription_endpoint == null
  endpoint = coalesce(
    var.sns_subscription_endpoint,
    try(
      "https://app.datadoghq.com/intake/webhook/sns?api_key=${data.aws_secretsmanager_secret_version.datadog_api_key[0].secret_string}",
      null
    )
  )
}

data "aws_kms_alias" "notifications" {
  name = "alias/rhythmic-notifications"
}

resource "aws_sns_topic" "cost_alerts" {
  name              = "Rhythmic-CostAlerts"
  kms_master_key_id = "alias/rhythmic-notifications"
  tags              = local.tags
}

data "aws_iam_policy_document" "cost_alerts" {
  statement {
    sid = "AllowCostAlerts"
    actions = [
      "sns:Publish"
    ]

    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.cost_alerts.arn
    ]
  }

  statement {
    sid = "AllowBudgetAlerts"
    actions = [
      "sns:Publish"
    ]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.cost_alerts.arn
    ]
  }
}

resource "aws_sns_topic_policy" "cost_alerts" {
  arn    = aws_sns_topic.cost_alerts.arn
  policy = data.aws_iam_policy_document.cost_alerts.json
}

data "aws_secretsmanager_secret" "datadog_api_key" {
  count = local.use_datadog_endpoint ? 1 : 0
  name  = var.datadog_api_key_secret_arn
}

data "aws_secretsmanager_secret_version" "datadog_api_key" {
  count     = local.use_datadog_endpoint ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.datadog_api_key[0].id
}

resource "aws_sns_topic_subscription" "cost_alerts" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "https"
  endpoint  = local.endpoint
}
