locals {
  launch_template_name = "${local.resource_prefix}-LaunchTemplate"
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

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NGAPShRoleBoundary"
}

resource "aws_iam_role_policy_attachment" "ec2_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.resource_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_policy" "s3fs_access_policy" {
  name        = "${local.resource_prefix}-S3FSAccessPolicy"

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

resource "aws_launch_template" "ssm_ami_launch_template" {
  image_id               = data.aws_ssm_parameter.ngap_ami.value
  instance_type          = "${var.instance_size}"
  name                   = local.launch_template_name
  vpc_security_group_ids = [aws_security_group.allow_all_egress.id]

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

  user_data = base64encode(templatefile("${path.module}/../user-data.sh.tpl", {
    s3fs_bucket_name = aws_s3_bucket.s3fs_bucket.id
    s3fs_directories = join(" ", var.s3fs_directories)
    aws_region = var.region
  }))

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
