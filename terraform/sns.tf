resource "aws_sns_topic" "ami_rotation" {
  name = "${local.resource_prefix}_ami_rotation"
}

resource "aws_sns_topic_policy" "ami_rotation_policy" {
  arn    = aws_sns_topic.ami_rotation.arn
  policy = data.aws_iam_policy_document.sns_ami_rotation_policy.json
}

data "aws_iam_policy_document" "sns_ami_rotation_policy" {
  statement {
    actions = ["SNS:Publish"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda_execution.arn]
    }
    resources = [aws_sns_topic.ami_rotation.arn]
  }
}

resource "aws_sns_topic_subscription" "notification_emails" {
  for_each   = toset(var.notification_emails)
  topic_arn  = aws_sns_topic.ami_rotation.arn
  protocol   = "email"
  endpoint   = each.value
}
