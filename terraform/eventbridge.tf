# eventbridge.tf

resource "aws_cloudwatch_event_rule" "cron_rule" {
  count = var.rotation_period > 0 ? 1 : 0

  name                = "${local.resource_prefix}_cron_rule"
  description         = "Triggers every 12 hours"
  schedule_expression = "cron(0 0 ? * SUN-SAT *)"
}

resource "aws_cloudwatch_event_target" "eventbridge_to_lambda" {
  count = var.rotation_period > 0 ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cron_rule[0].name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.ami_rotation.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.rotation_period > 0 ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ami_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron_rule[0].arn
}

resource "aws_iam_role" "eventbridge" {
  name               = "${local.resource_prefix}_eventbridge_ssm_role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_role.minified_json
}

data "aws_iam_policy_document" "eventbridge_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "eventbridge_lambda" {
  name   = "${local.resource_prefix}_eventbridge_lambda_policy"
  role   = aws_iam_role.eventbridge.name
  policy = data.aws_iam_policy_document.eventbridge_lambda.minified_json
}

data "aws_iam_policy_document" "eventbridge_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.ami_rotation.arn]
  }
}