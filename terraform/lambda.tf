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

resource "aws_iam_role" "lambda_role" {
  name = "${local.resource_prefix}_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_ssm_ec2" {
  name        = "${local.resource_prefix}_lambda_ssm_ec2_policy"
  description = "Allows Lambda to read SSM and update EC2 launch templates"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:StartInstanceRefresh"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:ModifyLaunchTemplate",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateLaunchTemplateVersion"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
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
