# 📖 Enterprise Deployment Guide

**Complete deployment documentation for ECS Slack Management System**

This guide provides production-grade deployment procedures with validation checkpoints and rollback strategies.

---

## 📋 Table of Contents

1. [Pre-Deployment Planning](#pre-deployment-planning)
2. [Environment Setup](#environment-setup)
3. [Slack Application Configuration](#slack-application-configuration)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Integration & Testing](#integration--testing)
6. [Production Validation](#production-validation)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Deployment](#post-deployment)

---

## Pre-Deployment Planning

### 1. Requirements Gathering

#### Business Requirements
- [ ] Identify ECS clusters requiring management access
- [ ] Define service restart authorization matrix
- [ ] Determine notification distribution lists
- [ ] Establish SLA requirements for command response time
- [ ] Document audit and compliance requirements

#### Technical Requirements
- [ ] AWS account with appropriate IAM permissions
- [ ] Existing ECS infrastructure (clusters + services)
- [ ] Slack workspace with app creation privileges
- [ ] Email addresses for notification recipients
- [ ] Approved maintenance window (if applicable)

### 2. Pre-Deployment Checklist

#### AWS Prerequisites

```bash
# Verify AWS CLI installation
aws --version
# Required: AWS CLI version 2.x or higher

# Validate AWS credentials
aws sts get-caller-identity
# Should return: UserId, Account, Arn

# Check current region
aws configure get region
# Example: ap-south-1

# List available ECS clusters
aws ecs list-clusters --output table

# For each cluster, list services
aws ecs list-services --cluster <cluster-name> --output table

# Verify IAM permissions (should not error)
aws lambda list-functions --max-items 1
aws apigateway get-rest-apis --limit 1
aws sns list-topics --max-items 1

# Check Terraform installation
terraform --version
# Required: Terraform v1.7.0 or higher

# Verify Terraform provider cache
terraform providers

# Check available disk space (need ~500MB)
df -h .

Perfect! Now let's create the second file.

📝 FILE 2: DEPLOYMENT_STEPS.md
bash
cd ~/micro-gitops-terraform/ecs-slack-management && cat > DEPLOYMENT_STEPS.md << 'EOFDEPLOYMENT'
# 📖 Enterprise Deployment Guide

**Complete deployment documentation for ECS Slack Management System**

This guide provides production-grade deployment procedures with validation checkpoints and rollback strategies.

---

## 📋 Table of Contents

1. [Pre-Deployment Planning](#pre-deployment-planning)
2. [Environment Setup](#environment-setup)
3. [Slack Application Configuration](#slack-application-configuration)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Integration & Testing](#integration--testing)
6. [Production Validation](#production-validation)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Deployment](#post-deployment)

---

## Pre-Deployment Planning

### 1. Requirements Gathering

#### Business Requirements
- [ ] Identify ECS clusters requiring management access
- [ ] Define service restart authorization matrix
- [ ] Determine notification distribution lists
- [ ] Establish SLA requirements for command response time
- [ ] Document audit and compliance requirements

#### Technical Requirements
- [ ] AWS account with appropriate IAM permissions
- [ ] Existing ECS infrastructure (clusters + services)
- [ ] Slack workspace with app creation privileges
- [ ] Email addresses for notification recipients
- [ ] Approved maintenance window (if applicable)

### 2. Pre-Deployment Checklist

#### AWS Prerequisites

```bash
# Verify AWS CLI installation
aws --version
# Required: AWS CLI version 2.x or higher

# Validate AWS credentials
aws sts get-caller-identity
# Should return: UserId, Account, Arn

# Check current region
aws configure get region
# Example: ap-south-1

# List available ECS clusters
aws ecs list-clusters --output table

# For each cluster, list services
aws ecs list-services --cluster <cluster-name> --output table

# Verify IAM permissions (should not error)
aws lambda list-functions --max-items 1
aws apigateway get-rest-apis --limit 1
aws sns list-topics --max-items 1
Terraform Prerequisites
bash
# Check Terraform installation
terraform --version
# Required: Terraform v1.7.0 or higher

# Verify Terraform provider cache
terraform providers

# Check available disk space (need ~500MB)
df -h .
Network Prerequisites
bash
# Test AWS API connectivity
curl -I https://ecs.ap-south-1.amazonaws.com
# Should return: HTTP/2 403 (forbidden, but reachable)

# Test Slack API connectivity  
curl -I https://slack.com/api/
# Should return: HTTP/2 200

# Verify DNS resolution
nslookup api.slack.com
nslookup execute-api.ap-south-1.amazonaws.com
3. Risk Assessment
Risk	Probability	Impact	Mitigation
Lambda deployment failure	Low	Medium	Terraform state rollback
Slack signature mismatch	Medium	High	Pre-validate signing secret
IAM permission denial	Low	High	Test IAM policy in staging
Cost overrun	Low	Low	Set billing alerts
Email delivery failure	Medium	Low	Use verified SES domain
Environment Setup
1. Project Structure Setup
bash
# Create project directory
mkdir -p ~/ecs-slack-management
cd ~/ecs-slack-management

# If cloning from GitHub:
git clone https://github.com/theradheshyampatil/ecs-slack-management.git .

# Verify directory structure
tree -L 2
# Expected output:
# .
# ├── lambda/
# │   ├── ecs_management_handler.py
# │   └── requirements.txt
# ├── terraform/
# │   ├── main.tf
# │   ├── variables.tf
# │   ├── outputs.tf
# │   └── terraform.tfvars.example
# ├── README.md
# └── LICENSE
2. Terraform State Backend (Production Best Practice)
Option A: S3 Backend (Recommended)

bash
# Create S3 bucket for state
aws s3 mb s3://ecs-slack-mgmt-terraform-state-${AWS_ACCOUNT_ID}

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ecs-slack-mgmt-terraform-state-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name ecs-slack-mgmt-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
Add to terraform/backend.tf:

text
terraform {
  backend "s3" {
    bucket         = "ecs-slack-mgmt-terraform-state-123456789012"
    key            = "production/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "ecs-slack-mgmt-terraform-locks"
    encrypt        = true
  }
}
Option B: Local State (Development Only)

bash
# Skip backend configuration
# State will be stored locally in terraform.tfstate
3. AWS Configuration Validation
bash
# Create IAM policy for deployment (if not admin)
cat > /tmp/ecs-slack-mgmt-deploy-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "apigateway:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "sns:*",
        "logs:*",
        "cloudwatch:*",
        "ecs:DescribeServices",
        "ecs:ListServices",
        "ecs:UpdateService",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create policy (optional - if not using admin credentials)
aws iam create-policy \
  --policy-name ECSSlackMgmtDeployment \
  --policy-document file:///tmp/ecs-slack-mgmt-deploy-policy.json
Slack Application Configuration
1. Create Slack App
Step-by-Step:

Navigate to Slack API Console

text
URL: https://api.slack.com/apps
Create New Application

Click: "Create New App"

Select: "From scratch"

App Name: ECS-Mgmt (or company-specific name)

Workspace: Select target workspace

Click: "Create App"

Record App Metadata

bash
# Save these values:
APP_ID="A0XXXXXXXXX"        # From Basic Information
APP_NAME="ECS-Mgmt"
WORKSPACE_ID="T0XXXXXXXXX"  # From workspace settings
2. Configure OAuth & Permissions
Navigate to "OAuth & Permissions"

Add Bot Token Scopes:

commands - Add shortcuts and/or slash commands

chat:write - Send messages as app

Save Changes

3. Obtain Signing Secret
Critical Security Component

bash
# Navigate to: Basic Information → App Credentials

# Copy Signing Secret
SLACK_SIGNING_SECRET="abc123def456ghi789..."

# Validate format (should be 32+ characters, alphanumeric)
echo $SLACK_SIGNING_SECRET | wc -c
# Should output: 33 or more

# Temporarily store (will be moved to terraform.tfvars)
echo "SLACK_SIGNING_SECRET=$SLACK_SIGNING_SECRET" > ~/.ecs-slack-secret
chmod 600 ~/.ecs-slack-secret
Security Note: Never commit signing secret to version control!

4. App Display Configuration (Optional)
text
Navigate to: Basic Information → Display Information

App Name: ECS Management
Short Description: Manage AWS ECS services from Slack
Background Color: #FF9900 (AWS orange)
Infrastructure Deployment
1. Terraform Configuration
Create Configuration File
bash
cd ~/ecs-slack-management/terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
Production Configuration Template
text
# ============================================
# CORE CONFIGURATION
# ============================================

project_name = "ecs-slack-mgmt"
environment  = "production"
aws_region   = "ap-south-1"

# ============================================
# SLACK INTEGRATION
# ============================================

slack_signing_secret = "paste_from_slack_app_credentials"

# ============================================
# NOTIFICATION CONFIGURATION
# ============================================

notification_emails = [
  "devops-team@company.com",
  "platform-engineering@company.com",
  "sre-oncall@company.com"
]

# ============================================
# ECS RESOURCE MAPPING
# ============================================

ecs_clusters = {
  
  # Production Cluster - Protected
  "production-us-east-1-main" = {
    services = [
      "api-gateway-service",
      "user-service",
      "payment-service",
      "notification-service",
      "worker-service"
    ]
    protected = true  # Email notifications enabled
  }
  
  # Production Cluster - Analytics
  "production-us-east-1-analytics" = {
    services = [
      "analytics-api",
      "data-processor",
      "reporting-service"
    ]
    protected = true
  }
  
  # Staging Environment
  "staging-us-east-1" = {
    services = [
      "staging-api",
      "staging-worker"
    ]
    protected = false  # No email notifications
  }
  
  # Development Environment  
  "dev-us-east-1" = {
    services = [
      "dev-api"
    ]
    protected = false
  }
}

# ============================================
# LAMBDA CONFIGURATION
# ============================================

lambda_memory_size = 512                    # MB
lambda_timeout     = 30                     # Seconds
lambda_runtime     = "python3.11"           # Runtime version

# ============================================
# API GATEWAY CONFIGURATION
# ============================================

api_rate_limit                 = 50         # Requests/second
api_burst_limit                = 100        # Burst capacity
api_stage_name                 = "production"

# ============================================
# MONITORING CONFIGURATION
# ============================================

enable_xray                    = true       # AWS X-Ray tracing
cloudwatch_log_retention_days  = 30         # Days
enable_detailed_monitoring     = true       # CloudWatch metrics

# ============================================
# ALARM THRESHOLDS
# ============================================

alarm_lambda_errors_threshold      = 5      # Errors in 5 minutes
alarm_lambda_throttles_threshold   = 10     # Throttles in 5 minutes
alarm_lambda_duration_threshold    = 25000  # Milliseconds
alarm_api_4xx_threshold            = 20     # 4xx errors in 5 minutes
alarm_api_5xx_threshold            = 5      # 5xx errors in 5 minutes
alarm_api_latency_threshold        = 2000   # Milliseconds

# ============================================
# TAGS (for cost allocation)
# ============================================

tags = {
  Project     = "ECS-Slack-Management"
  Environment = "Production"
  ManagedBy   = "Terraform"
  CostCenter  = "Platform-Engineering"
  Owner       = "devops-team@company.com"
}
Validate Configuration
bash
# Check syntax
terraform fmt -check

# Validate configuration
terraform validate

# Expected output:
# Success! The configuration is valid.
2. Terraform Initialization
bash
cd ~/ecs-slack-management/terraform

# Initialize Terraform
terraform init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# - Finding latest version of hashicorp/aws...
# - Installing hashicorp/aws v5.x.x...
# Terraform has been successfully initialized!

# Verify providers
terraform providers

# Expected output:
# Providers required by configuration:
# └── provider[registry.terraform.io/hashicorp/aws]
3. Pre-Deployment Validation
Dry Run (Plan)
bash
# Generate execution plan
terraform plan -out=tfplan

# Review plan carefully:
# - Check resource counts (should be ~25-30 resources)
# - Verify no resources will be destroyed (in fresh deployment)
# - Validate cluster/service names match your AWS environment

# Save plan summary
terraform show -json tfplan | jq '.resource_changes | length'
# Should output: 28 (approximate)
Validation Checklist
 Lambda function will be created

 API Gateway REST API will be created

 IAM role with appropriate policies will be created

 SNS topic and email subscriptions will be created

 CloudWatch log groups will be created

 CloudWatch alarms will be configured

 All cluster names match AWS ECS clusters

 All service names match ECS services

 No unexpected resource deletions

4. Infrastructure Deployment
bash
# Deploy infrastructure
terraform apply tfplan

# Deployment will take 2-4 minutes
# Monitor progress for any errors

# Expected final output:
# Apply complete! Resources: 28 added, 0 changed, 0 destroyed.
# Outputs:
# api_gateway_url = "https://abc123xyz.execute-api.ap-south-1.amazonaws.com/production/slack"
# lambda_function_name = "ecs-slack-mgmt-production-handler"
# ...
Post-Deployment Validation
bash
# 1. Verify Lambda function exists
aws lambda get-function \
  --function-name ecs-slack-mgmt-production-handler \
  --query 'Configuration.[FunctionName,Runtime,MemorySize,Timeout]' \
  --output table

# 2. Verify API Gateway
terraform output api_gateway_url

# Test API Gateway endpoint (should return 401 - unauthorized, which is correct)
curl -X POST $(terraform output -raw api_gateway_url)

# 3. Verify SNS topic
aws sns list-topics | grep ecs-slack-mgmt

# 4. Verify CloudWatch log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/ecs-slack-mgmt \
  --query 'logGroups[*].logGroupName' \
  --output table

# 5. Verify IAM role
aws iam get-role \
  --role-name ecs-slack-mgmt-production-lambda-role \
  --query 'Role.[RoleName,Arn]' \
  --output table
5. Output Documentation
bash
# Save all outputs for reference
terraform output > deployment-outputs.txt

# Save critical values
echo "API_GATEWAY_URL=$(terraform output -raw api_gateway_url)" >> ~/.ecs-slack-deployment
echo "LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)" >> ~/.ecs-slack-deployment
echo "SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)" >> ~/.ecs-slack-deployment

# Secure the file
chmod 600 ~/.ecs-slack-deployment
Integration & Testing
1. Configure Slack Slash Command
Create Command
Navigate to Slack App Settings

text
https://api.slack.com/apps/YOUR_APP_ID/slash-commands
Click "Create New Command"

Configure Command Details:

text
Command: /ecs-status
Request URL: [Paste api_gateway_url from terraform output]
Short Description: Manage AWS ECS services
Usage Hint: cluster=<name> service=<name> action=<status|restart>
Save Configuration

Validate Configuration
bash
# The Request URL should be:
echo $(terraform output -raw api_gateway_url)
# Format: https://xxxxx.execute-api.region.amazonaws.com/production/slack

# Verify URL is accessible (should return 401 or 403, not timeout)
curl -X POST -I $(terraform output -raw api_gateway_url)
2. Install App to Workspace
Navigate to "Install App" in left sidebar

Click "Install to Workspace"

Review Permissions:

Add shortcuts and/or slash commands

Send messages as ECS-Mgmt

Click "Allow"

Verify Installation:

Should see: "Successfully installed to [Workspace Name]"

Bot User OAuth Token will be generated (not needed for this implementation)

3. Email Subscription Confirmation
bash
# 1. Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --query 'Subscriptions[*].[Endpoint,SubscriptionArn]' \
  --output table

# 2. For each email showing "PendingConfirmation":
#    - Check email inbox (and spam folder!)
#    - Click "Confirm subscription" link
#    - Verify confirmation page appears

# 3. Re-check subscription status (should show ARN, not "Pending")
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --query 'Subscriptions[*].[Endpoint,SubscriptionArn]' \
  --output table
4. Testing Protocol
Test 1: Help Command
bash
# In Slack, execute:
/ecs-status help

# Expected Response (within 2 seconds):
# ✅ Command help documentation displayed
# ✅ Shows command syntax
# ✅ Shows examples
# ✅ Response marked as "Only visible to you"

# Verify in CloudWatch Logs:
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 2m \
  --filter-pattern "help"
Test 2: Service Status (Non-Critical Service)
bash
# Choose a non-critical service for testing
# Example: development or staging environment

# In Slack, execute:
/ecs-status cluster=dev-us-east-1 service=dev-api

# Expected Response (within 3-5 seconds):
# ✅ Service status report displayed
# ✅ Shows: cluster, service, status, task counts
# ✅ Shows: CPU utilization, deployment info
# ✅ Shows: recent events

# Verify response accuracy:
aws ecs describe-services \
  --cluster dev-us-east-1 \
  --services dev-api \
  --query 'services.[status,runningCount,desiredCount]'

# Check CloudWatch Logs:
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 5m \
  --format short
Test 3: Service Status (Production Service)
bash
# Test with production service (read-only operation)
/ecs-status cluster=production-us-east-1-main service=api-gateway-service

# Validation:
# ✅ Returns within 5 seconds
# ✅ Data matches AWS Console
# ✅ No errors in CloudWatch Logs
Test 4: Service Restart (Non-Production)
⚠️ CAUTION: This will restart the service!

bash
# Only test in dev/staging environment first!
/ecs-status cluster=dev-us-east-1 service=dev-api action=restart

# Expected Response:
# ✅ "Service Restart Initiated" message
# ✅ Shows deployment ID
# ✅ Shows user who initiated
# ✅ Shows timestamp

# Verify in AWS:
aws ecs describe-services \
  --cluster dev-us-east-1 \
  --services dev-api \
  --query 'services.deployments' \
  --output table

# Should show new deployment with "PRIMARY" status

# Check for email notification (if cluster is protected):
# ✅ Email received within 1 minute
# ✅ Contains correct cluster/service info
# ✅ Shows user who triggered restart
Test 5: Error Handling
bash
# Test 5a: Invalid cluster name
/ecs-status cluster=nonexistent service=api

# Expected: Error message indicating cluster not found

# Test 5b: Invalid service name
/ecs-status cluster=dev-us-east-1 service=nonexistent

# Expected: Error message indicating service not found

# Test 5c: Missing parameters
/ecs-status cluster=dev-us-east-1

# Expected: Error message showing correct usage

# Verify error handling in logs:
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler \
  --since 10m \
  --filter-pattern "ERROR"
Production Validation
1. Load Testing (Optional but Recommended)
bash
# Create test script
cat > /tmp/load-test.sh << 'EOF'
#!/bin/bash
for i in {1..50}; do
  curl -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "X-Slack-Request-Timestamp: $(date +%s)" \
    -H "X-Slack-Signature: v0=test" \
    -d "text=cluster=dev service=api" \
    $(terraform output -raw api_gateway_url) &
done
wait
EOF

chmod +x /tmp/load-test.sh
/tmp/load-test.sh

# Monitor Lambda metrics during load test
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Maximum
2. Performance Baseline
bash
# Record baseline metrics
echo "=== Performance Baseline ===" > /tmp/performance-baseline.txt
echo "Date: $(date)" >> /tmp/performance-baseline.txt

# Lambda duration
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=ecs-slack-mgmt-production-handler \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average,Maximum \
  >> /tmp/performance-baseline.txt

# API Gateway latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Latency \
  --dimensions Name=ApiName,Value=ecs-slack-mgmt-production-api \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average,Maximum \
  >> /tmp/performance-baseline.txt

cat /tmp/performance-baseline.txt
3. Security Validation
bash
# Verify signature verification is working
# This should FAIL (return 401):
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "text=help" \
  $(terraform output -raw api_gateway_url)

# Response should be: {"error": "Invalid signature"}
# If it returns actual data, signature verification is BROKEN!

# Check IAM policy
aws iam get-role-policy \
  --role-name ecs-slack-mgmt-production-lambda-role \
  --policy-name ecs-policy \
  --query 'PolicyDocument' \
  --output json

# Verify least-privilege access
4. Monitoring Validation
bash
# Check all CloudWatch alarms are OK
aws cloudwatch describe-alarms \
  --alarm-name-prefix ecs-slack-mgmt-production \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

# All alarms should show: OK (not ALARM or INSUFFICIENT_DATA)

# Verify X-Ray tracing (if enabled)
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --query 'TraceSummaries[0:5]'
Rollback Procedures
Scenario 1: Deployment Failure During Apply
bash
# Terraform will automatically rollback on failure
# If partial deployment occurred:

# 1. Check Terraform state
terraform show

# 2. Identify failed resources
terraform plan

# 3. Destroy problematic resources
terraform destroy -target=aws_lambda_function.ecs_management

# 4. Re-apply
terraform apply
Scenario 2: Configuration Error After Deployment
bash
# 1. Revert to previous configuration
git checkout HEAD~1 terraform/terraform.tfvars

# 2. Re-apply
terraform apply -auto-approve

# 3. Verify rollback
terraform output
Scenario 3: Complete Infrastructure Removal
bash
# WARNING: This will destroy ALL resources!

# 1. Backup state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)

# 2. Destroy all resources
terraform destroy -auto-approve

# 3. Verify deletion
aws lambda list-functions | grep ecs-slack-mgmt
# Should return nothing
Scenario 4: Lambda Function Issues
bash
# Rollback Lambda function only
terraform taint aws_lambda_function.ecs_management
terraform apply -target=aws_lambda_function.ecs_management -auto-approve
Post-Deployment
1. Documentation
bash
# Create deployment record
cat > deployment-record.md << EOF
# ECS Slack Management Deployment

**Date:** $(date)
**Deployed By:** $(whoami)
**AWS Account:** $(aws sts get-caller-identity --query Account --output text)
**Region:** $(aws configure get region)

## Deployment Details

- API Gateway URL: $(terraform output -raw api_gateway_url)
- Lambda Function: $(terraform output -raw lambda_function_name)
- SNS Topic: $(terraform output -raw sns_topic_arn)

## Configuration

- Total Clusters: $(terraform output -json ecs_clusters | jq 'length')
- Total Services: $(terraform output -json ecs_clusters | jq '[.[].services[]] | length')
- Protected Clusters: $(terraform output -json ecs_clusters | jq '[.[] | select(.protected == true)] | length')

## Validation Tests

- [x] Help command successful
- [x] Service status retrieval successful
- [x] Service restart successful (dev environment)
- [x] Email notifications working
- [x] CloudWatch logs captured
- [x] CloudWatch alarms configured

## Next Steps

1. Train team members on usage
2. Update incident response playbooks
3. Schedule quarterly review
4. Monitor costs after 30 days

EOF

cat deployment-record.md
2. Team Communication
Slack Announcement Template:

text
🚀 **NEW: ECS Service Management from Slack**

We've deployed a new tool that lets you manage ECS services directly from Slack!

**What you can do:**
-  Check service status: `/ecs-status cluster=prod service=api`
-  Restart services: `/ecs-status cluster=prod service=api action=restart`
-  Get help: `/ecs-status help`

**Available clusters:**
-  production-us-east-1-main (protected - sends email on restart)
-  staging-us-east-1
-  dev-us-east-1

**Documentation:**
https://github.com/yourorg/ecs-slack-management

**Questions?** Ask in #devops-help
3. Operational Runbook
Create runbook at: docs/runbook.md

text
# ECS Slack Management Runbook

## Daily Operations

**Check system health:**
```bash
aws cloudwatch describe-alarms --alarm-name-prefix ecs-slack-mgmt
View recent commands:

bash
aws logs tail /aws/lambda/ecs-slack-mgmt-production-handler --since 24h --filter-pattern "Command received"
Troubleshooting
Issue: Commands not working

Check CloudWatch Logs

Verify Slack signing secret

Test API Gateway endpoint

Issue: Slow response

Check Lambda duration metrics

Consider increasing memory

Review ECS API latency

Maintenance
Monthly tasks:

Review costs

Check alarm history

Update service mappings

Rotate Slack signing secret (every 90 days)

Emergency Contacts
Platform Team: platform@company.com

On-call: +1-XXX-XXX-XXXX

text

### 4. Cost Monitoring Setup

```bash
# Create billing alarm (requires CloudWatch in us-east-1)
aws cloudwatch put-metric-alarm \
  --alarm-name ecs-slack-mgmt-monthly-cost \
  --alarm-description "Alert if monthly cost exceeds $10" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 10.0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ServiceName,Value=AWSLambda Name=Currency,Value=USD \
  --alarm-actions $(terraform output -raw sns_topic_arn) \
  --region us-east-1
Deployment Checklist
Pre-Deployment
 AWS credentials configured

 Terraform installed and validated

 ECS clusters and services identified

 Slack app created

 Signing secret obtained

 Email addresses prepared

 Maintenance window scheduled (if required)

Deployment
 Terraform configuration created

 Configuration validated (terraform validate)

 Execution plan reviewed (terraform plan)

 Infrastructure deployed (terraform apply)

 Deployment outputs documented

 Resources validated in AWS Console

Integration
 Slack slash command configured

 App installed to workspace

 Email subscriptions confirmed

 Help command tested

 Service status tested (dev/staging)

 Service restart tested (dev/staging)

 Error handling validated

Production Validation
 Load testing completed (optional)

 Performance baseline recorded

 Security validation passed

 Monitoring alarms verified

 Cost tracking configured

Post-Deployment
 Deployment record created

 Team announcement sent

 Operational runbook created

 Billing alerts configured

 Quarterly review scheduled

Appendix
A. Terraform State Management
bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show aws_lambda_function.ecs_management

# Move resource in state (if refactoring)
terraform state mv aws_lambda_function.old aws_lambda_function.new

# Remove resource from state (without destroying)
terraform state rm aws_lambda_function.ecs_management
B. Useful AWS CLI Commands
bash
# Lambda function details
aws lambda get-function --function-name ecs-slack-mgmt-production-handler

# Invoke Lambda directly (for testing)
aws lambda invoke \
  --function-name ecs-slack-mgmt-production-handler \
  --payload '{"body":"text=help"}' \
  /tmp/lambda-response.json

# API Gateway details
terraform output -json | jq -r '.api_gateway_url.value'

# CloudWatch Insights query
aws logs start-query \
  --log-group-name /aws/lambda/ecs-slack-mgmt-production-handler \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | sort @timestamp desc | limit 20'
C. Common Error Messages
Error	Cause	Solution
dispatch_failed	Invalid Slack signature	Verify signing secret in terraform.tfvars
Service not found	Incorrect service/cluster name	Check exact names in AWS ECS
Task timed out	Lambda timeout too low	Increase lambda_timeout value
Rate exceeded	Too many requests	API Gateway throttling - expected behavior
AccessDeniedException	IAM permissions missing	Verify Lambda execution role
Deployment Complete! 🎉

For ongoing operations, refer to QUICK_START.md

Questions? Contact: radheshyam9096@gmail.com
