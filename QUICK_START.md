# ⚡ Quick Reference Guide

**Enterprise quick reference for ECS Slack Management System**

---

## 📋 Command Syntax

```bash
/ecs-status [cluster=<name>] [service=<name>] [action=<status|restart>]

Parameters:

cluster - ECS cluster name (required)

service - ECS service name (required)

action - Operation to perform (optional, default: status)

🎯 Common Operations
Help & Documentation
bash
/ecs-status help
Check Service Status
bash
# Basic status check
/ecs-status cluster=production service=api

# Returns:
# - Service health status
# - Task counts (desired/running/pending)
# - CPU/Memory utilization
# - Recent deployment events
# - Last 3 service events
Restart Service
bash
# Trigger rolling restart
/ecs-status cluster=production service=api action=restart

# Returns:
# - Deployment ID
# - Confirmation message
# - User attribution
# - Timestamp
# Note: Email sent if cluster is protected
📚 Environment-Specific Examples
Production
bash
# API Gateway
/ecs-status cluster=production-us-east-1-main service=api-gateway-service

# User Service
/ecs-status cluster=production-us-east-1-main service=user-service

# Payment Service (with restart)
/ecs-status cluster=production-us-east-1-main service=payment-service action=restart
Staging
bash
# Staging API
/ecs-status cluster=staging-us-east-1 service=staging-api

# Staging Worker
/ecs-status cluster=staging-us-east-1 service=staging-worker action=restart
Development
bash
# Dev API
/ecs-status cluster=dev-us-east-1 service=dev-api action=restart
🔧 Administrative Commands
View Deployment Outputs
bash
cd ~/ecs-slack-management/terraform
terraform output
Check System Health
bash
# CloudWatch alarms status
aws cloudwatch describe-alarms \
  --alarm-name-prefix ecs-slack-mgmt-production \
  --query 'MetricAlarms[?StateValue!=`OK`].[AlarmName,StateValue]' \
  --output table

# If empty output = all systems operational
View Recent Activity
bash
# Last 30 minutes of commands
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 30m \
  --filter-pattern "Command received"

# Last hour, formatted
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 1h \
  --format short
Real-time Log Monitoring
bash
# Follow logs (press Ctrl+C to stop)
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler --follow
⚙️ Configuration Management
Add New Service
bash
# 1. Edit configuration
cd ~/ecs-slack-management/terraform
nano terraform.tfvars

# 2. Add service to appropriate cluster
ecs_clusters = {
  "production-us-east-1-main" = {
    services  = [
      "existing-service-1",
      "existing-service-2",
      "new-service-name"  # ← Add here
    ]
    protected = true
  }
}

# 3. Apply changes
terraform apply -auto-approve

# 4. Test immediately
/ecs-status cluster=production-us-east-1-main service=new-service-name
Deployment time: ~30 seconds
Downtime: None

Add New Cluster
bash
# 1. Edit configuration
nano terraform/terraform.tfvars

# 2. Add new cluster block
ecs_clusters = {
  # Existing clusters...
  
  # New cluster
  "new-cluster-name" = {
    services  = ["service1", "service2"]
    protected = true  # true = email notifications
  }
}

# 3. Apply
terraform apply -auto-approve

# 4. Test
/ecs-status cluster=new-cluster-name service=service1
Add Email Recipient
bash
# 1. Edit configuration
nano terraform/terraform.tfvars

# 2. Add email to list
notification_emails = [
  "existing@company.com",
  "new-person@company.com"  # ← Add here
]

# 3. Apply
terraform apply -auto-approve

# 4. Notify new person to check email and confirm subscription
Update Lambda Configuration
bash
# 1. Edit terraform.tfvars
nano terraform/terraform.tfvars

# 2. Modify Lambda settings
lambda_memory_size = 1024  # Increase from 512 MB
lambda_timeout     = 60    # Increase from 30 seconds

# 3. Apply
terraform apply -auto-approve

# Takes effect immediately
🔍 Troubleshooting
Quick Diagnostics
bash
# 1. Check recent errors
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 15m \
  --filter-pattern "ERROR"

# 2. Check API Gateway health
curl -X POST $(cd terraform && terraform output -raw api_gateway_url)
# Should return: 401 Unauthorized (this is correct!)

# 3. Check SNS subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn $(cd terraform && terraform output -raw sns_topic_arn) \
  --query 'Subscriptions[*].[Endpoint,SubscriptionArn]' \
  --output table
Common Issues & Fixes
Issue: "dispatch_failed" in Slack
Fix:

bash
# Verify signing secret
cd terraform
grep slack_signing_secret terraform.tfvars

# Update if incorrect
nano terraform.tfvars
terraform apply -auto-approve
Issue: Service Not Found
Fix:

bash
# List exact cluster names
aws ecs list-clusters --output table

# List exact service names
aws ecs list-services --cluster your-cluster-name --output table

# Use exact names (case-sensitive!)
Issue: No Email Received
Fix:

bash
# Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn $(cd terraform && terraform output -raw sns_topic_arn)

# Look for "PendingConfirmation" → check spam folder
# Look for confirmed emails → verify cluster is protected

# Ensure cluster has protected = true
grep -A 3 "your-cluster" terraform/terraform.tfvars
Issue: Slow Response
Fix:

bash
# Check Lambda duration
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 900 \
  --statistics Average,Maximum

# If average > 3000ms, increase memory:
nano terraform/terraform.tfvars
# Change: lambda_memory_size = 1024
terraform apply -auto-approve
Issue: Command Timeout
Fix:

bash
# Increase Lambda timeout
nano terraform/terraform.tfvars
# Change: lambda_timeout = 60
terraform apply -auto-approve
📊 Monitoring & Metrics
Performance Metrics
bash
# Lambda invocations (last 24h)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --query 'Datapoints.Sum'

# Error rate (last 1h)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --query 'Datapoints.Sum'
Cost Tracking
bash
# Estimated monthly cost based on usage
INVOCATIONS=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 2592000 \
  --statistics Sum \
  --query 'Datapoints.Sum' \
  --output text)

echo "Monthly invocations: $INVOCATIONS"
echo "Estimated Lambda cost: \$0.00 - \$0.02"
echo "Estimated total cost: \$2.00 - \$5.00"
Audit Trail
bash
# Who restarted what (last 7 days)
aws logs filter-log-events \
  --log-group-name /aws/lambda/ecs-slack-mgmt-production-handler \
  --filter-pattern "action=restart" \
  --start-time $(date -d '7 days ago' +%s)000 \
  --query 'events[*].message' \
  --output text

# All commands by specific user (last 30 days)
aws logs filter-log-events \
  --log-group-name /aws/lambda/ecs-slack-mgmt-production-handler \
  --filter-pattern "john.doe" \
  --start-time $(date -d '30 days ago' +%s)000
🛠️ Maintenance Tasks
Daily
bash
# Quick health check
aws cloudwatch describe-alarms \
  --alarm-name-prefix ecs-slack-mgmt-production \
  --state-value ALARM

# Expected: No output (all OK)
Weekly
bash
# Review error logs
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 7d \
  --filter-pattern "ERROR"

# Review restart activity
aws logs filter-log-events \
  --log-group-name /aws/lambda/ecs-slack-mgmt-production-handler \
  --filter-pattern "action=restart" \
  --start-time $(date -d '7 days ago' +%s)000 \
  | jq -r '.events[].message'
Monthly
bash
# Review costs
echo "Monthly metrics for $(date +'%B %Y'):"
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 2592000 \
  --statistics Sum

# Backup Terraform state
cd ~/ecs-slack-management/terraform
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
Quarterly (Every 90 Days)
bash
# Rotate Slack signing secret
# 1. Generate new secret in Slack app settings
# 2. Update terraform.tfvars
# 3. Apply changes

nano terraform/terraform.tfvars
# Update: slack_signing_secret = "new_secret_here"

terraform apply -auto-approve

# Test immediately
/ecs-status help
🚨 Emergency Procedures
Disable System Temporarily
bash
# Option 1: Delete API Gateway deployment (reversible)
cd ~/ecs-slack-management/terraform
terraform taint aws_api_gateway_deployment.slack_deployment
terraform apply -auto-approve

# Commands will fail with connection error
# Restore by running terraform apply again
Complete System Shutdown
bash
# Destroys all infrastructure
cd ~/ecs-slack-management/terraform

# Backup state first!
cp terraform.tfstate terraform.tfstate.backup.emergency

# Destroy everything
terraform destroy -auto-approve

# To restore: terraform apply -auto-approve
Rollback Lambda Function
bash
# If new deployment has issues
cd ~/ecs-slack-management/terraform

terraform taint aws_lambda_function.ecs_management
terraform apply -target=aws_lambda_function.ecs_management -auto-approve
Emergency Notification Broadcast
bash
# Send test notification to all recipients
aws sns publish \
  --topic-arn $(cd terraform && terraform output -raw sns_topic_arn) \
  --subject "ECS Slack Management - Test Notification" \
  --message "This is a test notification. If you receive this, your email subscription is working correctly."
📞 Support & Escalation
Get Help
Documentation:

README.md - Complete documentation

DEPLOYMENT_STEPS.md - Detailed deployment guide

External Resources:

AWS ECS Documentation

Slack API Documentation

Terraform AWS Provider

Issues & Bugs:

GitHub Issues: https://github.com/theradheshyampatil/ecs-slack-management/issues

Email: radheshyam9096@gmail.com

Escalation Path
Level 1: Self-Service

Check logs: aws logs tail /aws/lambda/... --follow

Review this quick start guide

Check troubleshooting section

Level 2: Team Support

Post in #devops-help Slack channel

Check with platform engineering team

Level 3: Maintainer

Email: radheshyam9096@gmail.com

GitHub: @theradheshyampatil

💡 Pro Tips
Slack Shortcuts
Pin frequently used commands:

text
Create a pinned message in #devops:

📌 Common ECS Commands

Production API:
/ecs-status cluster=production-us-east-1-main service=api-gateway-service

Staging API:
/ecs-status cluster=staging-us-east-1 service=staging-api
Use Slack reminders for status checks:

text
/remind #devops to check API health every weekday at 9am
Bash Aliases
Add to ~/.bashrc or ~/.zshrc:

bash
# ECS Slack Management aliases
alias ecs-logs='aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler --follow'
alias ecs-logs-error='aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler --filter-pattern ERROR'
alias ecs-config='cd ~/ecs-slack-management/terraform && nano terraform.tfvars'
alias ecs-apply='cd ~/ecs-slack-management/terraform && terraform apply -auto-approve'
alias ecs-status='cd ~/ecs-slack-management/terraform && terraform output'
alias ecs-alarms='aws cloudwatch describe-alarms --alarm-name-prefix ecs-slack-mgmt-production --query "MetricAlarms[*].[AlarmName,StateValue]" --output table'
Reload: source ~/.bashrc

VS Code Snippets
Create .vscode/ecs-slack.code-snippets:

json
{
  "ECS Status Check": {
    "prefix": "ecs-status",
    "body": [
      "/ecs-status cluster=${1:cluster-name} service=${2:service-name}"
    ]
  },
  "ECS Restart": {
    "prefix": "ecs-restart",
    "body": [
      "/ecs-status cluster=${1:cluster-name} service=${2:service-name} action=restart"
    ]
  }
}
Incident Response Workflow
text
1. Alert received → Check service status in Slack
   /ecs-status cluster=production service=api

2. If service unhealthy → Review recent events
   (shown in status response)

3. If needed → Restart service
   /ecs-status cluster=production service=api action=restart

4. Monitor → Check status every 2 minutes
   Wait for deployment to stabilize

5. Document → Update incident ticket with:
   - Service restarted via Slack
   - Deployment ID from response
   - Time to recovery
📊 Reporting & Analytics
Generate Usage Report
bash
cat > /tmp/usage-report.sh << 'EOF'
#!/bin/bash
echo "=== ECS Slack Management Usage Report ==="
echo "Report Date: $(date)"
echo ""

# Total invocations this month
INVOCATIONS=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 2592000 \
  --statistics Sum \
  --query 'Datapoints.Sum' \
  --output text)

echo "Total Commands: $INVOCATIONS"

# Error count
ERRORS=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 2592000 \
  --statistics Sum \
  --query 'Datapoints.Sum' \
  --output text)

echo "Total Errors: ${ERRORS:-0}"

# Success rate
if [ ! -z "$INVOCATIONS" ] && [ ! -z "$ERRORS" ]; then
  SUCCESS_RATE=$(echo "scale=2; 100 - ($ERRORS * 100 / $INVOCATIONS)" | bc)
  echo "Success Rate: ${SUCCESS_RATE}%"
fi

echo ""
echo "Most active users (last 30 days):"
aws logs filter-log-events \
  --log-group-name /aws/lambda/ecs-slack-mgmt-production-handler \
  --filter-pattern "Command received" \
  --start-time $(date -d '30 days ago' +%s)000 \
  | jq -r '.events[].message' \
  | grep -oP '(?<=from )\w+' \
  | sort | uniq -c | sort -rn | head -10

echo ""
echo "Service restart count:"
aws logs filter-log-events \
  --log-group-name /aws/lambda/ecs-slack-mgmt-production-handler \
  --filter-pattern "action=restart" \
  --start-time $(date -d '30 days ago' +%s)000 \
  | jq -r '.events[].message' \
  | grep -oP '(?<=service=)[^ ]+' \
  | sort | uniq -c | sort -rn
EOF

chmod +x /tmp/usage-report.sh
/tmp/usage-report.sh
✅ Daily Checklist
Morning:

 Check CloudWatch alarms: ecs-alarms (if using alias)

 Review overnight activity: ecs-logs-error (if using alias)

 Verify system responsive: /ecs-status help in Slack

After Changes:

 Test commands in dev environment first

 Verify changes in staging

 Document changes in team wiki

End of Day:

 Review any error notifications received

 Check if email subscriptions need updating

 Confirm no alarms in ALARM state

🎓 Training Resources
New User Onboarding
What to share with new team members:

Show basic commands:

text
/ecs-status help
/ecs-status cluster=dev-us-east-1 service=dev-api
Explain when to use:

Service not responding? Check status

After deployment? Check status

High CPU/memory? Check metrics in status

Need to restart? Use restart action

Important rules:

Always check status before restart

Never restart production during business hours (unless emergency)

Document all restarts in incident tickets

Ask if unsure which cluster/service

Share documentation:

This quick start guide

README.md for detailed info

Team wiki with service mappings

Practice Exercises
Safe commands for practice:

text
# These are read-only and safe to practice:
/ecs-status help
/ecs-status cluster=dev-us-east-1 service=dev-api
/ecs-status cluster=staging-us-east-1 service=staging-api

# Practice restart ONLY in dev:
/ecs-status cluster=dev-us-east-1 service=dev-api action=restart
📝 Command Cheat Sheet
Action	Command
Help	/ecs-status help
Status	/ecs-status cluster=NAME service=NAME
Restart	/ecs-status cluster=NAME service=NAME action=restart
View Logs	aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler --follow
Check Alarms	aws cloudwatch describe-alarms --alarm-name-prefix ecs-slack-mgmt
Update Config	nano terraform/terraform.tfvars && terraform apply
View Outputs	terraform output
Email Status	aws sns list-subscriptions-by-topic --topic-arn ARN
Keep this guide bookmarked! 📌

Questions? Ask in #devops-help or email radheshyam9096@gmail.com

Found a bug? Open an issue

Last updated: February 2026
