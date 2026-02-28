locals {
  launch_template_name = "${local.resource_prefix}-LaunchTemplate"

   bootstrap_sh = templatefile(
    "${path.module}/../bootstrap/bootstrap.sh.tftpl",
    {
      s3fs_bucket_name = aws_s3_bucket.s3fs_bucket.id
      s3fs_directories = join(" ", var.s3fs_directories)
      aws_region       = var.region
      python_version   = var.python_version
      python_cmd       = "python${var.python_version}"
      ssm_uid          = "1001"
      ssm_gid          = "1001"
      pipx_bin_dir     = "/usr/local/bin"
      pipx_home_dir    = "/opt/pipx"
    }
   )

   cloud_init = templatefile(
    "${path.module}/../bootstrap/cloud-init.yml.tftpl",
    {
      inject_bash_sh = base64encode(file("${path.module}/../bootstrap/inject_bash.sh"))
      bootstrap_sh = base64encode(local.bootstrap_sh),
      modify_logging_py = base64encode(file("${path.module}/../bootstrap/modify_logging.py"))
    }
   )
}

resource "aws_autoscaling_group" "main_asg" {
  name                      = "${local.resource_prefix}-Main"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size

  vpc_zone_identifier = data.aws_subnets.private.ids

  launch_template {
    id      = aws_launch_template.ssm_ami_launch_template.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_notification" "main" {
  group_names = [aws_autoscaling_group.main_asg.name]
  topic_arn  = aws_sns_topic.asg_notifications.arn
  notifications = ["autoscaling:EC2_INSTANCE_TERMINATE"]
}

resource "aws_security_group" "allow_all_egress" {
  name        = "${local.resource_prefix}-allow-all-egress-sg"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_cloudwatch_log_group" "carpathia" {
  name = "/service/carpathia"
}

data "aws_iam_policy" "ngap_sh_role_boundary" {
  count = var.permissions_boundary_policy_name != null ? 1 : 0
  name = var.permissions_boundary_policy_name
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.resource_prefix}-ec2-role"

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

  permissions_boundary = var.permissions_boundary_policy_name != null ? data.aws_iam_policy.ngap_sh_role_boundary[0].arn : null
}

resource "aws_iam_role_policy_attachment" "ec2_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.resource_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

data "aws_iam_policy_document" "base_ec2" {
  statement {
    sid = "S3FSAccess"

    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.s3fs_bucket.arn,
      "${aws_s3_bucket.s3fs_bucket.arn}/*"
    ]
  }
}

data "aws_iam_policy" "cloudwatch_agent_server_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "base_ec2" {
  name = "${local.resource_prefix}-BaseEC2Policy"
  role   = aws_iam_role.ec2_role.name
  policy = data.aws_iam_policy_document.base_ec2.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = data.aws_iam_policy.cloudwatch_agent_server_policy.arn
}

resource "aws_launch_template" "ssm_ami_launch_template" {
  image_id               = data.aws_ssm_parameter.ngap_ami.value
  instance_type          = "${var.instance_size}"
  name                   = local.launch_template_name
  vpc_security_group_ids = [aws_security_group.allow_all_egress.id]
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda" // This is typically the root device for Amazon Linux/Ubuntu
    ebs {
      volume_size = var.ebs_size_gb
      volume_type = "gp3"
      delete_on_termination = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      image_id,
    ]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  user_data = base64encode(local.cloud_init)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name            = "${local.resource_prefix}-Instance"
      Launch_Template = local.launch_template_name
    }
  }
}

# S3FS bucket + directories
resource "aws_s3_bucket" "s3fs_bucket" {
  bucket = "${local.resource_prefix}-ec2"
}

resource "aws_s3_bucket_policy" "s3fs_bucket_policy" {
  count = length(var.read_only_accounts) > 0 ? 1 : 0

  bucket = aws_s3_bucket.s3fs_bucket.id
  policy = data.aws_iam_policy_document.s3fs_bucket_policy.minified_json
}

data "aws_iam_policy_document" "s3fs_bucket_policy" {
  statement {
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.s3fs_bucket.arn]
    principals {
      type        = "AWS"
      identifiers = [
        for account in var.read_only_accounts : "arn:aws:iam::${account}:root"
      ]
    }
  }

  statement {
    actions = ["s3:GetObject", "s3:GetObjectTagging"]
    resources = ["${aws_s3_bucket.s3fs_bucket.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [
        for account in var.read_only_accounts : "arn:aws:iam::${account}:root"
      ]
    }
  }
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
