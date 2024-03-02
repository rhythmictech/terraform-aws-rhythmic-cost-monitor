data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitor_sps_and_ris_execution" {
  name_prefix        = "Rhythmic-MonitorSPsAndRIs"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "monitor_sps_and_ris_execution" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeReservedInstances",
      "rds:DescribeReservedDBInstances",
      "redshift:DescribeReservedNodes",
      "savingsplans:DescribeSavingsPlans",
      "savingsplans:DescribeSavingsPlanRates",
      "savingsplans:ListTagsForResource"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/monitor_sps_and_ris_execution:*"]

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }

  statement {
    effect    = "Allow"
    resources = [aws_sns_topic.cost_alerts.arn]

    actions = [
      "sns:Publish"
    ]
  }
}

resource "aws_iam_policy" "monitor_sps_and_ris_execution" {
  name   = "lambda_policy"
  policy = data.aws_iam_policy_document.monitor_sps_and_ris_execution.json
}

resource "aws_iam_role_policy_attachment" "monitor_sps_and_ris_execution" {
  role       = aws_iam_role.monitor_sps_and_ris_execution.name
  policy_arn = aws_iam_policy.monitor_sps_and_ris_execution.arn
}

data "archive_file" "monitor_sps_and_ris" {
  type        = "zip"
  source_file = "${path.module}/monitor_sps_and_ris.py"
  output_path = "${path.module}/monitor_sps_and_ris.zip"
}

resource "aws_lambda_function" "monitor_sps_and_ris" {
  function_name    = "monitor_sps_and_ris_execution"
  handler          = "monitor_sps_and_ris.lambda_handler"
  role             = aws_iam_role.monitor_sps_and_ris_execution.arn
  runtime          = "python3.9"
  filename         = data.archive_file.monitor_sps_and_ris.output_path
  source_code_hash = filebase64sha256(data.archive_file.monitor_sps_and_ris.output_path)
  tags             = local.tags

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.cost_alerts.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "monitor_sps_and_ris" {
  name              = "/aws/lambda/${aws_lambda_function.monitor_sps_and_ris.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_event_rule" "monitor_sps_and_ris" {
  name        = "monitor-sps-and-ris-daily-trigger"
  description = "Triggers Lambda at noon ET every day"
  #schedule_expression = "cron(0 17 * * ? *)"
  schedule_expression = "cron(0,15,30,45 * * * ? *)"
}

resource "aws_lambda_permission" "monitor_sps_and_ris" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitor_sps_and_ris.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitor_sps_and_ris.arn
}

resource "aws_cloudwatch_event_target" "monitor_sps_and_ris" {
  rule      = aws_cloudwatch_event_rule.monitor_sps_and_ris.name
  target_id = "invokeLambdaFunction"
  arn       = aws_lambda_function.monitor_sps_and_ris.arn

  input = jsonencode({
    "warning_exp" : "600",
    "alert_exp" : "500"
  })
}
