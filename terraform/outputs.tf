# ============================================================================
# TERRAFORM OUTPUTS - All outputs consolidated here
# ============================================================================

# Critical outputs for Slack setup
output "STEP_1_SLACK_REQUEST_URL" {
  description = "⚠️ COPY THIS URL to Slack App → Slash Commands → Request URL"
  value       = "${aws_api_gateway_stage.production.invoke_url}/slack"
}

output "STEP_2_EMAIL_CONFIRMATION" {
  description = "Email confirmation required"
  value       = var.enable_notifications ? "Check emails: ${join(", ", var.notification_emails)} for AWS confirmation" : "Email notifications disabled"
}

output "STEP_3_TEST_COMMAND" {
  description = "Test in Slack"
  value       = "/ecs-status_cluster=my-demo-app-cluster_service=my-demo-app-service"
}

# Main API URL
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = "${aws_api_gateway_stage.production.invoke_url}/slack"
}

# Resource names
output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.ecs_management.function_name
}

output "lambda_log_group_name" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "api_log_group_name" {
  description = "CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway_logs.name
}

# Configuration info
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "protected_clusters_list" {
  description = "List of protected clusters"
  value       = local.protected_clusters
}

output "total_services" {
  description = "Total services managed"
  value       = length(local.all_service_mappings)
}

# Monitoring commands
output "view_lambda_logs_command" {
  description = "Command to view Lambda logs"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda_logs.name} --follow"
}

output "view_api_logs_command" {
  description = "Command to view API Gateway logs"
  value       = "aws logs tail ${aws_cloudwatch_log_group.api_gateway_logs.name} --follow"
}

# SNS info
output "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  value       = var.enable_notifications ? aws_sns_topic.notifications[0].arn : "Notifications disabled"
}
