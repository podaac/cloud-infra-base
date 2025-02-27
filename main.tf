provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  tags = {
    "Name" : "Application VPC"
  }
}

data "aws_ssm_parameter" "parameter_for_ami" {
  name = var.ssm_parameter 
}

data "aws_subnets" "private" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.default.id]
    }

    filter {
        name   = "tag:Name"
        values = ["Private application*"]
    }
}

# S3 Bucket for Lambda Deployment
resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = "${local.resource-prefix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Upload Lambda ZIP to S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "${var.app_name}_lambda_function.zip"
  source = "${var.app_name}_lambda_function.zip"
  etag   = filemd5("${var.app_name}_lambda_function.zip")
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name = "${local.resource-prefix}_lambda_ssm_role"

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

# Attach necessary IAM Policies to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_ssm_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Deploy Lambda from S3
resource "aws_lambda_function" "ssm_handler" {
  function_name    = "${local.resource-prefix}_lambda"
  s3_bucket       = aws_s3_bucket.lambda_bucket.id
  s3_key          = aws_s3_object.lambda_zip.key
  role            = aws_iam_role.lambda_role.arn
  handler         = "${var.app_name}_lambda_function.lambda_handler"
  runtime         = "python3.13"
  timeout         = 30
  # Force update when the zip file changes
  source_code_hash = filebase64sha256("${var.app_name}_lambda_function.zip")
  environment {
    variables = {
      SSM_PARAMETER_FOR_AMI = data.aws_ssm_parameter.parameter_for_ami.name
      LAUNCH_TEMPLATE_NAME  = "${local.launch-template-name}"
      AUTO_SCALING_GROUP_NAME = "${local.auto-scaling-group-name}"
    }
  }
}

# EventBridge Rule for cron_rule
resource "aws_cloudwatch_event_rule" "cron_rule" {
  name                = "${local.resource-prefix}_cron_rule"
  description         = "Triggers on Friday at midnight UTC"
  schedule_expression = "cron(0 0 ? * 6 *)"
}
# Have it run the 10th minute after the hour
# schedule_expression = "cron(10 * ? * * *)"

# EventBridge Target 
 resource "aws_cloudwatch_event_target" "eventbridge_to_lambda" {
   rule      = aws_cloudwatch_event_rule.cron_rule.name
   target_id = "SendToLambda"
   arn       = aws_lambda_function.ssm_handler.arn
 }

# EventBridge Target Trigger
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ssm_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron_rule.arn
}

# IAM Role for EventBridge to invoke Lambda
resource "aws_iam_role" "eventbridge_role" {
  name = "${local.resource-prefix}_eventbridge_ssm_role"

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

# IAM Policy for EventBridge to invoke Lambda
resource "aws_iam_policy" "eventbridge_policy" {
  name        = "${local.resource-prefix}_eventbridge_ssm_policy"
  description = "Allows EventBridge to invoke the Lambda function"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "${aws_lambda_function.ssm_handler.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eventbridge_lambda_attach" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_ssm_ec2_policy" {
  name        = "${local.resource-prefix}_lambda_ssm_ec2_policy"
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
      # "Resource": "${data.aws_ssm_parameter.parameter_for_ami.arn}"
# Attach policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_ssm_ec2_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ssm_ec2_policy.arn
}

# Create an Auto Scaling Group that uses the launch template
resource "aws_autoscaling_group" "main_asg" {
  name                      = "${local.auto-scaling-group-name}"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.ssm_ami_launch_template.id
    version = "$Latest"
  }

  vpc_zone_identifier = data.aws_subnets.private.ids
}

resource "aws_security_group" "allow_all_egress" {
  name        = "${local.resource-prefix}-allow-all-egress-sg"
  vpc_id      = data.aws_vpc.default.id

  # Allow all outbound traffic (any protocol, any destination)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.resource-prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NGAPShRoleBoundary"
}

resource "aws_iam_role_policy_attachment" "ec2_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.resource-prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Create S3FS Buckets
resource "aws_s3_bucket" "s3fs_bucket" {
  bucket = "${local.resource-prefix}-ec2"
}

resource "aws_s3_object" "s3fs_directories" {
  for_each = toset(var.s3fs_directories)

  bucket  = aws_s3_bucket.s3fs_bucket.id
  key     = each.value
  acl     = "private"
  content = ""
  lifecycle {
    ignore_changes = [
      metadata
    ]
  }
}

resource "aws_iam_policy" "s3fs_access_policy" {
  name        = "${local.resource-prefix}-S3FSAccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [
          aws_s3_bucket.s3fs_bucket.arn,
          "${aws_s3_bucket.s3fs_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3fs_access_policy.arn
}

# Create a launch template
resource "aws_launch_template" "ssm_ami_launch_template" {
  image_id               = data.aws_ssm_parameter.parameter_for_ami.value
  instance_type          = "${var.instance_size}"
  name                   = "${local.launch-template-name}"
  vpc_security_group_ids = [aws_security_group.allow_all_egress.id]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      image_id,
    ]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  user_data = base64encode(templatefile("user-data.sh.tpl", {
    s3fs_bucket_name = aws_s3_bucket.s3fs_bucket.id
    s3fs_directories = join(" ", var.s3fs_directories)
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name            = "${local.resource-prefix}-Instance"
      Launch_Template = "${local.launch-template-name}"
    }
  }
}