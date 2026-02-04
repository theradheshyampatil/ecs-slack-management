# Lambda Function Configuration

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../build/lambda.zip"
  
  excludes = [
    ".git",
    ".gitignore",
    "*.pyc",
    "__pycache__",
    "*.md",
    ".DS_Store",
    "tests/"
  ]
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = local.log_group_name
  retention_in_days = var.lambda_log_retention_days
  
  tags = {
    Name = "${local.name_prefix}-lambda-logs"
  }
}

resource "aws_lambda_function" "ecs_management" {
  function_name = local.lambda_function_name
  description   = "ECS Service Management via Slack"
  role          = aws_iam_role.lambda_role.arn
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  handler = "ecs_management_handler.lambda_handler"
  runtime = "python3.11"
  
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
  
  environment {
    variables = {
      SLACK_SIGNING_SECRET    = var.slack_signing_secret
      SNS_TOPIC_ARN           = var.enable_notifications ? aws_sns_topic.notifications[0].arn : ""
      PROTECTED_CLUSTERS      = local.protected_clusters_string
      ENABLE_DETAILED_METRICS = var.enable_detailed_metrics ? "true" : "false"
      MAX_TASKS_TO_SHOW       = tostring(var.max_tasks_to_show)
      LOG_LEVEL               = "INFO"
      ENVIRONMENT             = var.environment
      PROJECT_NAME            = var.project_name
    }
  }
  
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
  
  tags = {
    Name = local.lambda_function_name
  }
  
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_ecs_policy
  ]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  alarm_description   = "Alert when Lambda function has errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ecs_management.function_name
  }
  
  alarm_actions = var.enable_notifications ? [aws_sns_topic.notifications[0].arn] : []
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name_prefix}-lambda-throttles"
  alarm_description   = "Alert when Lambda function is throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ecs_management.function_name
  }
  
  alarm_actions = var.enable_notifications ? [aws_sns_topic.notifications[0].arn] : []
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.name_prefix}-lambda-duration"
  alarm_description   = "Alert when Lambda function is slow"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 30000
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ecs_management.function_name
  }
  
  alarm_actions = var.enable_notifications ? [aws_sns_topic.notifications[0].arn] : []
}
