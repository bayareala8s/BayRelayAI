terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Lambda errors for ${each.key}"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = var.tags
}

variable "name_prefix" {
  type = string
}

variable "lambda_function_names" {
  type = map(string)
}

variable "error_threshold" {
  type    = number
  default = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "alarm_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

resource "aws_sns_topic_subscription" "alarm_email" {
  for_each = toset(var.alarm_subscription_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

variable "alarm_subscription_emails" {
  type        = list(string)
  default     = []
  description = "Email addresses to subscribe to Lambda error alarms (confirm via SNS email)."
}
