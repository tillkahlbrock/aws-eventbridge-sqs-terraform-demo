locals {
  tags = merge({
    ManagedBy   = "Terraform"
    Environment = "demo"
    Component   = "consumer"
  }, var.tags)

  # Accept both a Terraform object and a ready JSON string.
  event_pattern_json = can(tostring(var.event_pattern)) ? tostring(var.event_pattern) : jsonencode(var.event_pattern)

  execution_role_name = coalesce(var.eventbridge_execution_role_name, "${var.subscription_name}-eventbridge-target")
  target_dlq_name     = coalesce(var.target_dlq_name, "${var.subscription_name}-target-dlq")
}

# --------------------------------------------------------------------------
# Consumer workload account
# --------------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  provider = aws.consumer

  name                      = var.dlq_name
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = local.tags
}

resource "aws_sqs_queue" "this" {
  provider = aws.consumer

  name                      = var.queue_name
  message_retention_seconds = var.message_retention_seconds
  tags                      = local.tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Only the consumer queue can move messages into the dead-letter queue.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  provider = aws.consumer

  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

# The queue policy names the platform-side execution role as the only principal
# that may send to the queue.
resource "aws_sqs_queue_policy" "this" {
  provider = aws.consumer

  queue_url = aws_sqs_queue.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPlatformEventBridgeExecutionRoleToSendMessages"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eventbridge_target.arn
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.this.arn
      }
    ]
  })
}

# --------------------------------------------------------------------------
# Platform account
# --------------------------------------------------------------------------

# EventBridge assumes this role to deliver events to the queue in the other account.
resource "aws_iam_role" "eventbridge_target" {
  provider = aws.platform

  name = local.execution_role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToAssumeTargetRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_target" {
  provider = aws.platform

  name = "send-message-to-consumer-queue"
  role = aws_iam_role.eventbridge_target.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendMessageToConsumerQueueOnly"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.this.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "this" {
  provider = aws.platform

  name           = var.subscription_name
  description    = "Delivers subscribed events from the shared bus to the consumer queue ${var.queue_name}."
  event_bus_name = var.event_bus_name
  event_pattern  = local.event_pattern_json
  tags           = local.tags
}

# EventBridge can fail to deliver: a wrong queue policy, a throttled target.
# Without this queue it drops the event after the retry window. The queue belongs
# to the rule, so it lives in the platform account.
resource "aws_sqs_queue" "target_dlq" {
  provider = aws.platform

  name                      = local.target_dlq_name
  message_retention_seconds = var.target_dlq_message_retention_seconds
  tags                      = local.tags
}

# Only this rule may park a failed delivery in the queue.
resource "aws_sqs_queue_policy" "target_dlq" {
  provider = aws.platform

  queue_url = aws_sqs_queue.target_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowThisRuleToSendFailedDeliveries"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.target_dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.this.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "this" {
  provider = aws.platform

  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = var.event_bus_name
  target_id      = var.subscription_name
  arn            = aws_sqs_queue.this.arn
  role_arn       = aws_iam_role.eventbridge_target.arn

  dead_letter_config {
    arn = aws_sqs_queue.target_dlq.arn
  }
}
