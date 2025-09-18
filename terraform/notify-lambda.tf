resource "aws_lambda_function" "notify" {
  function_name    = "${local.resource_prefix}_ami_rotation"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "notify.lambda_handler"
  runtime         = "python3.13"
  timeout         = 60

  filename = "${path.module}/../build/carpathia-lambdas-${local.version}.zip"
  source_code_hash = filebase64sha256("${path.module}/../build/carpathia-lambdas-${local.version}.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.ami_rotation.arn
    }
  }
}

data "aws_iam_policy_document" "notify_lambda" {
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
  assume_role_policy = data.aws_iam_policy_document.notify_lambda.minified_json
}

data "aws_iam_policy_document" "notify_lambda_policies" {
  statement {
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.ami_rotation.arn]
  }
  
  statement {
    actions = ["lambda:ListTags"]
    resources = [aws_lambda_function.notify.arn]
  }
}

resource "aws_iam_role_policy" "notify_lambda" {
  name   = "${local.resource_prefix}_notify_lambda_policy"
  role   = aws_iam_role.notify_lambda.arn
  policy = data.aws_iam_policy_document.notify_lambda_policies.json
}

resource "aws_iam_role_policy_attachment" "notify_lambda_basic_execution" {
  role       = aws_iam_role.notify_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
