resource "aws_sns_topic" "email" {
  name = "${local.resource_prefix}_email"
}

resource "aws_sns_topic_policy" "email_policy" {
  arn    = aws_sns_topic.email.arn
  policy = data.aws_iam_policy_document.sns_email_policy.json
}

data "aws_iam_policy_document" "sns_email_policy" {
  statement {
    actions = ["SNS:Publish"]
    principals {
      type        = "AWS"
      identifiers = [
        aws_iam_role.notify_lambda.arn,
        aws_iam_role.autorotate_lambda.arn
      ]
    }
    resources = [aws_sns_topic.email.arn]
  }
}

resource "aws_sns_topic" "asg_notifications" {
  name = "${local.resource_prefix}_asg_notifications"
}

resource "aws_sns_topic_subscription" "notification_emails" {
  for_each   = toset(var.notification_emails)
  topic_arn  = aws_sns_topic.email.arn
  protocol   = "email"
  endpoint   = each.value

  lifecycle {
    prevent_destroy = true
  }
}
