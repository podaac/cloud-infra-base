resource "aws_lambda_function" "ami_rotation" {
  function_name    = "${local.resource_prefix}_ami_rotation"
  role            = aws_iam_role.lambda_role.arn
  handler         = "${var.app_name}_lambda_function.lambda_handler"
  runtime         = "python3.13"
  timeout         = 60

  filename = "${path.module}/../${var.app_name}_lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/../${var.app_name}_lambda_function.zip")

  environment {
    variables = {
      SSM_PARAMETER_FOR_AMI = data.aws_ssm_parameter.ngap_ami.name
      LAUNCH_TEMPLATE_NAME  = aws_launch_template.ssm_ami_launch_template.name
      AUTO_SCALING_GROUP_NAME = aws_autoscaling_group.main_asg.name
    }
  }
}

data "aws_iam_policy_document" "lambda_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.resource_prefix}_lambda_role"

  assume_role_policy = data.aws_iam_policy_document.lambda_role.minified_json
}

data "aws_iam_policy_document" "lambda_ssm_ec2" {
  statement {
    actions = ["ssm:GetParameter"]
    resources = [data.aws_ssm_parameter.ngap_ami.arn]
  }

  statement {
    actions = ["autoscaling:StartInstanceRefresh"]
    resources = [aws_autoscaling_group.main_asg.arn]
  }

  statement {
    actions = [
      "ec2:ModifyLaunchTemplate",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions"
    ]
    resources = [aws_launch_template.ssm_ami_launch_template.arn]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.ami_rotation.function_name}",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.ami_rotation.function_name}:*"
    ]
  }
}

resource "aws_iam_policy" "lambda_ssm_ec2" {
  name        = "${local.resource_prefix}_lambda_ssm_ec2_policy"
  description = "Allows Lambda to read SSM and update EC2 launch templates"

  policy = data.aws_iam_policy_document.lambda_ssm_ec2.minified_json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_ec2" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ssm_ec2.arn
}

resource "aws_iam_role_policy_attachment" "lambda_ssm" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
