# API Gateway Configuration

resource "aws_api_gateway_rest_api" "slack_api" {
  name        = local.api_gateway_name
  description = "API Gateway for ECS Slack management"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  minimum_compression_size = 1024
  
  tags = merge(
    local.common_tags,
    {
      Name        = local.api_gateway_name
      Purpose     = "Slack-Command-Endpoint"
      Integration = "Lambda"
    }
  )
}

resource "aws_api_gateway_resource" "slack_resource" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  parent_id   = aws_api_gateway_rest_api.slack_api.root_resource_id
  path_part   = "slack"
}

resource "aws_api_gateway_method" "slack_post" {
  rest_api_id   = aws_api_gateway_rest_api.slack_api.id
  resource_id   = aws_api_gateway_resource.slack_resource.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.header.X-Slack-Signature"          = true
    "method.request.header.X-Slack-Request-Timestamp" = true
  }
}

resource "aws_api_gateway_integration" "slack_lambda" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  resource_id = aws_api_gateway_resource.slack_resource.id
  http_method = aws_api_gateway_method.slack_post.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ecs_management.invoke_arn
  
  timeout_milliseconds = 29000
}

resource "aws_api_gateway_method_response" "slack_response_200" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  resource_id = aws_api_gateway_resource.slack_resource.id
  http_method = aws_api_gateway_method.slack_post.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Content-Type" = true
  }
  
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "slack_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  resource_id = aws_api_gateway_resource.slack_resource.id
  http_method = aws_api_gateway_method.slack_post.http_method
  status_code = aws_api_gateway_method_response.slack_response_200.status_code
  
  depends_on = [
    aws_api_gateway_integration.slack_lambda
  ]
}

resource "aws_api_gateway_deployment" "slack_deployment" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.slack_resource.id,
      aws_api_gateway_method.slack_post.id,
      aws_api_gateway_integration.slack_lambda.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_integration.slack_lambda,
    aws_api_gateway_method.slack_post
  ]
}

resource "aws_api_gateway_stage" "production" {
  deployment_id        = aws_api_gateway_deployment.slack_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.slack_api.id
  stage_name           = var.environment
  xray_tracing_enabled = var.enable_xray_tracing
  
  tags = merge(
    local.common_tags,
    {
      Name  = "${local.name_prefix}-api-stage"
      Stage = var.environment
    }
  )
  
  depends_on = [
    aws_api_gateway_account.main
  ]
}

resource "aws_api_gateway_usage_plan" "slack_usage_plan" {
  name        = "${local.name_prefix}-usage-plan"
  description = "Usage plan for Slack ECS management API"
  
  throttle_settings {
    rate_limit  = var.api_throttling_rate_limit
    burst_limit = var.api_burst_limit
  }
  
  api_stages {
    api_id = aws_api_gateway_rest_api.slack_api.id
    stage  = aws_api_gateway_stage.production.stage_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${local.api_gateway_name}"
  retention_in_days = var.lambda_log_retention_days
  
  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-api-logs"
      Purpose = "API-Gateway-Access-Logs"
    }
  )
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_management.function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_api_gateway_rest_api.slack_api.execution_arn}/*/*"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${local.name_prefix}-api-4xx-errors"
  alarm_description   = "Alert when API Gateway has high 4XX error rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.slack_api.name
    Stage   = aws_api_gateway_stage.production.stage_name
  }
  
  alarm_actions = var.enable_notifications ? [aws_sns_topic.notifications[0].arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${local.name_prefix}-api-5xx-errors"
  alarm_description   = "Alert when API Gateway has 5XX errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.slack_api.name
    Stage   = aws_api_gateway_stage.production.stage_name
  }
  
  alarm_actions = var.enable_notifications ? [aws_sns_topic.notifications[0].arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${local.name_prefix}-api-latency"
  alarm_description   = "Alert when API Gateway latency is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 10000
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.slack_api.name
    Stage   = aws_api_gateway_stage.production.stage_name
  }
  
  alarm_actions = var.enable_notifications ? [aws_sns_topic.notifications[0].arn] : []
  
  tags = local.common_tags
}
