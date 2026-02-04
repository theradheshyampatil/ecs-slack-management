# ============================================================================
# 🔒 IAM CONFIGURATION - Security & Permissions
# ============================================================================
#
# This file is heavily commented for team understanding
# All security permissions are defined here with explanations
#
# ============================================================================

resource "aws_iam_role" "lambda_role" {
  name        = "${local.name_prefix}-lambda-role"
  description = "IAM role for ECS Slack management Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  max_session_duration = 3600

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-lambda-role"
      Purpose = "Lambda-Execution-Role"
    }
  )
}

# ECS Operations Policy
resource "aws_iam_policy" "lambda_ecs_policy" {
  name        = "${local.name_prefix}-lambda-ecs-policy"
  description = "Allows Lambda to describe and update ECS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSReadOperations"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSUpdateOperations"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-policy"
    }
  )
}

# CloudWatch Metrics Policy
resource "aws_iam_policy" "lambda_cloudwatch_metrics_policy" {
  name        = "${local.name_prefix}-lambda-cloudwatch-metrics-policy"
  description = "Allows Lambda to read and write CloudWatch metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetricsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetricsWrite"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "ECS/SlackManagement"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cloudwatch-policy"
    }
  )
}

# SNS Policy
resource "aws_iam_policy" "lambda_sns_policy" {
  count = var.enable_notifications ? 1 : 0

  name        = "${local.name_prefix}-lambda-sns-policy"
  description = "Allows Lambda to publish to SNS topic"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNSPublishToNotificationTopic"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.notifications[0].arn
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-sns-policy"
    }
  )
}

# X-Ray Policy
resource "aws_iam_policy" "lambda_xray_policy" {
  count = var.enable_xray_tracing ? 1 : 0

  name        = "${local.name_prefix}-lambda-xray-policy"
  description = "Allows Lambda to send trace data to X-Ray"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayWriteAccess"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-xray-policy"
    }
  )
}

# Attach Policies to Role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ecs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ecs_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_metrics_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_metrics_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy" {
  count      = var.enable_notifications ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sns_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "lambda_xray_policy" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_xray_policy[0].arn
}

# SNS Topic
resource "aws_sns_topic" "notifications" {
  count = var.enable_notifications ? 1 : 0

  name         = local.sns_topic_name
  display_name = "ECS Slack Management Notifications"

  tags = merge(
    local.common_tags,
    {
      Name = local.sns_topic_name
    }
  )
}

# SNS Email Subscriptions
resource "aws_sns_topic_subscription" "email_notifications" {
  for_each = var.enable_notifications ? toset(var.notification_emails) : []

  topic_arn = aws_sns_topic.notifications[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "notifications_policy" {
  count = var.enable_notifications ? 1 : 0
  arn   = aws_sns_topic.notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.notifications[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.ecs_management.arn
          }
        }
      }
    ]
  })
}

# Outputs


# API Gateway CloudWatch Logs Role
resource "aws_iam_role" "apigateway_cloudwatch_role" {
  name = "${local.name_prefix}-apigateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apigateway_cloudwatch" {
  role       = aws_iam_role.apigateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch_role.arn
}
