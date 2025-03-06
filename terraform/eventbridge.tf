resource "aws_cloudwatch_event_rule" "cron_rule" {
  name                = "${local.resource_prefix}_cron_rule"
  description         = "Triggers on Friday at midnight UTC"
  schedule_expression = "cron(0 0 ? * 6 *)"
}

resource "aws_cloudwatch_event_target" "eventbridge_to_lambda" {
  rule      = aws_cloudwatch_event_rule.cron_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.ami_rotation.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ami_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron_rule.arn
}

resource "aws_iam_role" "eventbridge" {
  name = "${local.resource_prefix}_eventbridge_ssm_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "eventbridge" {
  name        = "${local.resource_prefix}_eventbridge_ssm_policy"
  description = "Allows EventBridge to invoke the Lambda function"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "${aws_lambda_function.ami_rotation.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eventbridge_lambda" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}
