resource "aws_lambda_function" "notify" {
  function_name    = "${local.resource_prefix}_notify"
  role            = aws_iam_role.notify_lambda.arn
  handler         = "notify.lambda_handler"
  runtime         = "python3.13"
  timeout         = 60

  filename = "${path.module}/../build/carpathia-lambdas-${local.version}.zip"
  source_code_hash = filebase64sha256("${path.module}/../build/carpathia-lambdas-${local.version}.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.email.arn
    }
  }
}

data "aws_iam_policy_document" "notify_lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notify_lambda" {
  name = "${local.resource_prefix}_notify_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.notify_lambda_assume.minified_json
}

data "aws_iam_policy_document" "notify_lambda_execution" {
  statement {
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.email.arn]
  }
  
  statement {
    actions = ["lambda:ListTags"]
    resources = [aws_lambda_function.notify.arn]
  }
}

resource "aws_iam_role_policy" "notify_lambda_execution" {
  name   = "${local.resource_prefix}_notify_lambda_policy"
  role   = aws_iam_role.notify_lambda.name
  policy = data.aws_iam_policy_document.notify_lambda_execution.json
}

resource "aws_iam_role_policy_attachment" "notify_lambda_basic_execution" {
  role       = aws_iam_role.notify_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_sns_topic_subscription" "asg_notifications" {
  topic_arn = aws_sns_topic.asg_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notify.arn
}

resource "aws_lambda_permission" "asg_notifications" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify.arn
  principal     = "sns.amazonaws.com"

  source_arn = aws_sns_topic.asg_notifications.arn
}
