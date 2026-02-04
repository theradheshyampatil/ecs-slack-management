# ============================================================================
# 🔧 TERRAFORM VARIABLES - Configuration Parameters
# ============================================================================
# 
# PURPOSE: This file defines ALL configurable parameters for the ECS Slack
#          management system. Think of this as a "settings menu" where you
#          can customize everything without touching the actual code.
#
# HOW IT WORKS:
#   1. We DEFINE variables here (what settings are available)
#   2. We SET their values in terraform.tfvars (your actual configuration)
#   3. Terraform uses these values to build your infrastructure
#
# FOR BEGINNERS:
#   - "variable" = a setting you can change
#   - "type" = what kind of data (string = text, number = number, etc.)
#   - "description" = what this setting does
#   - "default" = the value used if you don't specify one
#
# ⚠️ DON'T EDIT THIS FILE - Edit terraform.tfvars instead!
# ============================================================================

# ----------------------------------------------------------------------------
# 📍 PROJECT INFORMATION
# ----------------------------------------------------------------------------
# These variables help identify your deployment and organize resources

variable "project_name" {
  description = "Name of your project (used in resource naming). Example: 'micro-gitops' or 'company-ecs-mgmt'"
  type        = string
  default     = "ecs-slack-mgmt"

  # WHAT THIS DOES: All AWS resources will be named like "ecs-slack-mgmt-lambda", 
  #                 "ecs-slack-mgmt-api-gateway", etc. This helps you identify
  #                 them in AWS Console and organize billing.
}

variable "environment" {
  description = "Environment name (dev, staging, production). Used for tagging and resource naming."
  type        = string
  default     = "production"

  # WHAT THIS DOES: Helps you separate different environments. If you deploy
  #                 to dev first, set this to "dev". For production, use "production".
  #                 Resources will be named like "ecs-slack-mgmt-production-lambda"
}

variable "aws_region" {
  description = "AWS region where all resources will be created. Must match your ECS cluster region!"
  type        = string
  default     = "ap-south-1"

  # ⚠️ IMPORTANT: This MUST be the same region where your ECS clusters are running!
  #              If your ECS is in ap-south-1 (Mumbai), keep this as ap-south-1.
  #              If you have clusters in us-east-1, change to "us-east-1"
}

# ----------------------------------------------------------------------------
# 🔐 SLACK CONFIGURATION (Security Critical!)
# ----------------------------------------------------------------------------

variable "slack_signing_secret" {
  description = "Slack app signing secret for request verification (REQUIRED for security)"
  type        = string
  sensitive   = true # This marks it as sensitive - won't show in logs

  # ⚠️ WHERE TO FIND THIS:
  #    1. Go to https://api.slack.com/apps
  #    2. Select your app
  #    3. Go to "Basic Information" → "App Credentials"
  #    4. Copy the "Signing Secret" (not Client Secret!)
  #
  # ⚠️ SECURITY: This is SECRET - never commit to Git or share publicly!
  #              The Lambda function uses this to verify requests really came
  #              from Slack and not from a hacker trying to control your servers.
  #
  # EXAMPLE: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
}

variable "slack_command_name" {
  description = "The slash command name users will type in Slack"
  type        = string
  default     = "/ecs-status"

  # WHAT THIS DOES: This is what your team types in Slack. Default is "/ecs-status"
  #                 but you can change to "/ecs", "/restart", "/service" etc.
  #                 Whatever you choose here, you must also configure in Slack app!
}

# ----------------------------------------------------------------------------
# 📧 NOTIFICATION CONFIGURATION
# ----------------------------------------------------------------------------
# Email alerts for important operations (like restarting production services)

variable "notification_emails" {
  description = "List of email addresses to notify for protected cluster operations"
  type        = list(string)
  default     = []

  # ⚠️ UPDATE WITH YOUR TEAM EMAILS:
  #    Example: ["radheshyam9096@gmail.com", "devops@company.com", "oncall@company.com"]
  #
  # WHAT THIS DOES: When someone restarts a protected cluster (production),
  #                 these emails get an alert with WHO did it, WHEN, and WHICH service.
  #                 Great for audit trail and security monitoring!
  #
  # HOW IT WORKS: Uses AWS SNS (Simple Notification Service) to send emails.
  #               You'll need to confirm email subscriptions (check spam folder!)
}

variable "enable_notifications" {
  description = "Enable/disable email notifications. Set to false to save costs in dev/testing"
  type        = bool
  default     = true

  # WHEN TO DISABLE: Set to false when testing or in dev environment to avoid spam
  # WHEN TO ENABLE: Always true in production for security and compliance!
}

# ----------------------------------------------------------------------------
# 🏢 ECS CLUSTER CONFIGURATION
# ----------------------------------------------------------------------------
# Define which clusters and services this system can manage

variable "ecs_clusters" {
  description = "Map of ECS clusters and their services that can be managed via Slack"
  type = map(object({
    services  = list(string) # List of service names in this cluster
    protected = bool         # If true, requires extra security (email notifications)
  }))

  # ⚠️ THIS IS WHERE YOU ADD YOUR 53 SERVICES!
  #
  # STRUCTURE EXPLAINED:
  #   cluster-name = {
  #     services  = ["service1", "service2", "service3"]  ← List all services here
  #     protected = true/false  ← true for production, false for dev/staging
  #   }
  #
  # EXAMPLE FOR YOUR SETUP:
  #   "my-demo-app-cluster" = {
  #     services  = ["my-demo-app-service"]
  #     protected = true
  #   }
  #
  # FOR 53 SERVICES ACROSS MULTIPLE CLUSTERS:
  #   "production-cluster-1" = {
  #     services  = ["api-service", "web-service", "auth-service", ...]  ← Add all 20 services
  #     protected = true
  #   }
  #   "production-cluster-2" = {
  #     services  = ["worker-1", "worker-2", ...]  ← Add remaining 33 services
  #     protected = true
  #   }
  #
  # 💡 TIP: You can have UNLIMITED clusters and services - just keep adding!
  #         No code changes needed, just edit terraform.tfvars and run "terraform apply"

  default = {}
}

variable "auto_protect_prod_clusters" {
  description = "Automatically mark clusters with 'prod' or 'production' in name as protected"
  type        = bool
  default     = true

  # WHAT THIS DOES: If true, any cluster with "prod" or "production" in its name
  #                 will automatically be treated as protected (emails + audit logs)
  #                 even if you forgot to set protected = true.
  #
  # SMART DEFAULTS: This catches mistakes! If you accidentally set a production
  #                 cluster to protected = false, this safety net still protects it.
  #
  # RECOMMENDATION: Keep this as "true" for enterprise security!
}

# ----------------------------------------------------------------------------
# ⚙️ LAMBDA FUNCTION CONFIGURATION
# ----------------------------------------------------------------------------
# Settings for the serverless function that does the actual work

variable "lambda_memory_size" {
  description = "Amount of memory (MB) allocated to Lambda function. More memory = faster but costs more"
  type        = number
  default     = 512

  # HOW TO CHOOSE:
  #   - 256 MB: Minimum, slower, cheaper (~$0.10/month) - OK for testing
  #   - 512 MB: Recommended, good balance (~$0.20/month) - Good for production
  #   - 1024 MB: Fast, costs more (~$0.40/month) - Use if you have slow responses
  #
  # 💡 TIP: Start with 512 MB. Monitor CloudWatch metrics. If function times out,
  #         increase memory. If it's always fast, you can reduce to 256 MB to save $.
}

variable "lambda_timeout" {
  description = "Maximum time (seconds) Lambda function can run before timing out"
  type        = number
  default     = 60

  # WHAT THIS MEANS: If the function doesn't respond within 60 seconds, it's killed.
  #
  # WHY 60 SECONDS?: ECS API calls usually take 2-5 seconds, CloudWatch metrics
  #                  take 3-8 seconds. Total ~10-15 seconds normally. 60s gives
  #                  plenty of buffer for slow AWS API responses.
  #
  # WHEN TO INCREASE: If you see timeout errors in CloudWatch logs
  # WHEN TO DECREASE: Never - 60s is safe and doesn't cost extra
}

variable "lambda_log_retention_days" {
  description = "How long to keep Lambda function logs in CloudWatch (days)"
  type        = number
  default     = 30

  # OPTIONS:
  #   - 7 days: Minimum, saves cost, good for dev
  #   - 30 days: Recommended, good balance, meets most compliance needs
  #   - 90 days: Enterprise, for SOC2/ISO27001 compliance
  #   - 365 days: Maximum, for strict compliance requirements
  #
  # COST IMPACT: More days = more storage cost (but still cheap: ~$0.50/GB/month)
  #
  # ⚠️ COMPLIANCE: If your company has compliance requirements (SOC2, ISO27001),
  #                check minimum log retention requirements! Usually 90+ days.
}

# ----------------------------------------------------------------------------
# 📊 MONITORING & OBSERVABILITY
# ----------------------------------------------------------------------------

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for performance monitoring and debugging"
  type        = bool
  default     = true

  # WHAT IS X-RAY?: A service that shows you exactly what your Lambda function
  #                 is doing - which AWS services it calls, how long each step takes.
  #
  # WHY ENABLE IT?: 
  #   - Troubleshooting: When something is slow, X-Ray shows you WHAT is slow
  #   - Performance: Track response times over days/weeks
  #   - Debugging: See exact API calls and their responses
  #
  # COST: Minimal (~$0.50/month for typical usage)
  #
  # WHEN TO DISABLE: Only in dev environment to save a few cents
}

variable "enable_detailed_metrics" {
  description = "Send custom CloudWatch metrics for monitoring (restart counts, errors, etc.)"
  type        = bool
  default     = true

  # WHAT THIS TRACKS:
  #   - How many times each service was restarted
  #   - How many errors occurred
  #   - Which clusters are used most
  #
  # WHY IT'S USEFUL:
  #   - Identify problematic services (if service X is restarted 20x/day, investigate!)
  #   - Usage statistics for reporting
  #   - Set up alarms (alert if restarts > 10/hour)
  #
  # COST: Very cheap (~$0.30/month for metrics)
}

variable "max_tasks_to_show" {
  description = "Maximum number of tasks to show in status response (prevents huge Slack messages)"
  type        = number
  default     = 5

  # WHAT THIS DOES: Limits how many running tasks are shown in Slack response.
  #                 If you have 50 tasks running, showing all 50 would create
  #                 a massive message. This limits to first 5.
  #
  # RECOMMENDATION: Keep at 5. If service has issues, you'll see the first few
  #                 tasks. For full details, users can check AWS Console.
}

# ----------------------------------------------------------------------------
# 🔒 SECURITY CONFIGURATION
# ----------------------------------------------------------------------------

variable "api_throttling_rate_limit" {
  description = "API Gateway requests per second limit (prevents abuse/DDoS)"
  type        = number
  default     = 50

  # WHAT THIS DOES: Limits how many requests can hit your API per second.
  #                 If someone tries to spam your endpoint, this stops them.
  #
  # HOW TO CHOOSE:
  #   - 10 req/sec: Small team (5-10 people), very conservative
  #   - 50 req/sec: Medium team (50 people), recommended - allows bursts
  #   - 100 req/sec: Large org (100+ people), allows heavy usage
  #
  # SECURITY: Protects against:
  #   - Accidental infinite loops in scripts
  #   - Malicious DDoS attempts
  #   - Runaway automation
  #
  # 💡 TIP: 50 is generous. Even if all 50 people typed command at exact same
  #         second, they'd all succeed. Normal usage is 1-5 requests/second.
}

variable "api_burst_limit" {
  description = "API Gateway burst limit (temporary spike allowance)"
  type        = number
  default     = 100

  # WHAT IS BURST?: Allows temporary spikes above rate limit.
  #                 Example: 50/sec sustained, but can handle 100/sec for a few seconds
  #
  # REAL WORLD: During incident, 10 engineers might all check service status
  #             at same time. Burst allows this without throttling them.
}

variable "enable_vpc_config" {
  description = "Deploy Lambda in VPC for enhanced security (advanced, usually not needed)"
  type        = bool
  default     = false

  # ⚠️ ADVANCED SETTING - MOST USERS SHOULD KEEP THIS FALSE!
  #
  # WHAT IS VPC?: Virtual Private Cloud - isolated network for extra security
  #
  # WHEN TO ENABLE:
  #   - Your company security policy requires all Lambda functions in VPC
  #   - You need to access internal resources (internal APIs, databases)
  #
  # WHEN TO KEEP FALSE (most cases):
  #   - This Lambda only calls AWS APIs (ECS, CloudWatch, SNS) - public endpoints
  #   - Enabling VPC adds complexity (need NAT gateway, costs $32/month more!)
  #   - No security benefit if only calling AWS services
  #
  # RECOMMENDATION: Keep FALSE unless security team specifically requires VPC
}

# ----------------------------------------------------------------------------
# 🏷️ TAGS (For Organization & Billing)
# ----------------------------------------------------------------------------

variable "common_tags" {
  description = "Common tags applied to all resources (for billing, organization, compliance)"
  type        = map(string)
  default = {
    Project     = "ECS-Slack-Management"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }

  # WHAT ARE TAGS?: Labels attached to AWS resources for organization
  #
  # WHY THEY MATTER:
  #   1. BILLING: Track costs by project, team, department
  #   2. ORGANIZATION: Find all resources for this project quickly
  #   3. COMPLIANCE: Required for many enterprise compliance frameworks
  #   4. AUTOMATION: Scripts can find resources by tags
  #
  # ⚠️ CUSTOMIZE THESE:
  #   - Add "Team" tag: "DevOps" or "Platform" or "SRE"
  #   - Add "CostCenter" tag: for billing department
  #   - Add "Owner" tag: your name or email
  #   - Add "Compliance" tag: "SOC2", "ISO27001", etc.
  #
  # EXAMPLE:
  #   common_tags = {
  #     Project     = "ECS-Slack-Management"
  #     Team        = "DevOps"
  #     Owner       = "radheshyam9096@gmail.com"
  #     CostCenter  = "Engineering"
  #     Compliance  = "SOC2"
  #     ManagedBy   = "Terraform"
  #   }
}

# ============================================================================
# 📝 END OF VARIABLES
# ============================================================================
# 
# NEXT STEPS:
#   1. Don't edit this file directly
#   2. Copy terraform.tfvars.example to terraform.tfvars
#   3. Edit terraform.tfvars with your actual values
#   4. Run: terraform plan (to see what will be created)
#   5. Run: terraform apply (to create the infrastructure)
#
# NEED HELP?: 
#   - Check README.md for detailed setup guide
#   - Check DEPLOYMENT_STEPS.md for step-by-step instructions
#   - Contact: radheshyam9096@gmail.com
# ============================================================================
