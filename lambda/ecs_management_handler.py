import json
import os
import boto3
import hmac
import hashlib
import time
from datetime import datetime, timezone
from urllib.parse import parse_qs

# Initialize AWS clients
ecs_client = boto3.client('ecs')
cloudwatch_client = boto3.client('cloudwatch')
sns_client = boto3.client('sns')

# Environment variables
SLACK_SIGNING_SECRET = os.environ.get('SLACK_SIGNING_SECRET', '')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
PROTECTED_CLUSTERS = os.environ.get('PROTECTED_CLUSTERS', '').split(',')

def verify_slack_signature(event):
    """Verify the request is from Slack using signature"""
    try:
        # API Gateway lowercases headers, so we need to handle both cases
        headers = event.get('headers', {})
        
        # Try both lowercase and original case
        slack_signature = (headers.get('x-slack-signature') or 
                          headers.get('X-Slack-Signature', ''))
        slack_request_timestamp = (headers.get('x-slack-request-timestamp') or 
                                   headers.get('X-Slack-Request-Timestamp', ''))
        
        if not slack_signature or not slack_request_timestamp:
            print(f"Missing signature or timestamp")
            return False
        
        # Check timestamp to prevent replay attacks
        request_time = int(slack_request_timestamp)
        if abs(time.time() - request_time) > 60 * 5:
            print(f"Request too old")
            return False
        
        # Verify signature
        sig_basestring = f"v0:{slack_request_timestamp}:{event['body']}"
        my_signature = 'v0=' + hmac.new(
            SLACK_SIGNING_SECRET.encode(),
            sig_basestring.encode(),
            hashlib.sha256
        ).hexdigest()
        
        is_valid = hmac.compare_digest(my_signature, slack_signature)
        if not is_valid:
            print(f"Signature mismatch")
        return is_valid
    except Exception as e:
        print(f"Signature verification error: {str(e)}")
        return False

def parse_parameters(text):
    """Parse command parameters from text"""
    params = {}
    
    # Remove extra whitespace
    text = text.strip()
    
    # Parse key=value pairs separated by spaces
    parts = text.split()
    for part in parts:
        if '=' in part:
            key, value = part.split('=', 1)
            params[key.strip()] = value.strip()
    
    return params

def get_service_status(cluster, service):
    """Get ECS service status and metrics"""
    try:
        # Describe service
        response = ecs_client.describe_services(
            cluster=cluster,
            services=[service]
        )
        
        if not response['services']:
            return {"error": f"Service '{service}' not found in cluster '{cluster}'"}
        
        service_data = response['services'][0]
        
        # Get running tasks
        tasks_response = ecs_client.list_tasks(
            cluster=cluster,
            serviceName=service,
            desiredStatus='RUNNING'
        )
        
        task_count = len(tasks_response.get('taskArns', []))
        
        # Get CloudWatch metrics (CPU/Memory)
        try:
            cpu_metric = cloudwatch_client.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='CPUUtilization',
                Dimensions=[
                    {'Name': 'ServiceName', 'Value': service},
                    {'Name': 'ClusterName', 'Value': cluster}
                ],
                StartTime=datetime.now(timezone.utc).replace(hour=0, minute=0),
                EndTime=datetime.now(timezone.utc),
                Period=300,
                Statistics=['Average']
            )
            
            cpu_avg = cpu_metric['Datapoints'][-1]['Average'] if cpu_metric['Datapoints'] else 0
        except:
            cpu_avg = 0
        
        # Format response
        status_text = f"""**Service Status Report**

**Cluster:** {cluster}
**Service:** {service}

**Status:** {service_data['status']}
**Desired Tasks:** {service_data['desiredCount']}
**Running Tasks:** {service_data['runningCount']}
**Pending Tasks:** {service_data['pendingCount']}

**CPU Utilization:** {cpu_avg:.1f}%

**Deployment:**
- Primary: {service_data['deployments'][0]['status'] if service_data['deployments'] else 'N/A'}
- Updated: {service_data['deployments'][0]['updatedAt'].strftime('%Y-%m-%d %H:%M:%S UTC') if service_data['deployments'] else 'N/A'}

**Events (Last 3):**
"""
        
        for event in service_data.get('events', [])[:3]:
            status_text += f"\n• {event['createdAt'].strftime('%H:%M:%S')} - {event['message']}"
        
        return {"status": status_text}
        
    except Exception as e:
        return {"error": f"Error getting service status: {str(e)}"}

def restart_service(cluster, service, user):
    """Restart ECS service by forcing new deployment"""
    try:
        # Force new deployment
        response = ecs_client.update_service(
            cluster=cluster,
            service=service,
            forceNewDeployment=True
        )
        
        deployment_id = response['service']['deployments'][0]['id']
        
        # Send notification if protected cluster
        if cluster in PROTECTED_CLUSTERS and SNS_TOPIC_ARN:
            try:
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject=f'ECS Service Restart - {cluster}/{service}',
                    Message=f"""ECS service restart initiated via Slack.

Cluster: {cluster}
Service: {service}
User: {user}
Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}
Deployment ID: {deployment_id}

This is an automated notification from ECS Slack Management.
"""
                )
            except Exception as e:
                print(f"SNS notification error: {str(e)}")
        
        return {"status": f"""**Service Restart Initiated** ✅

**Cluster:** {cluster}
**Service:** {service}
**Deployment ID:** {deployment_id}
**User:** {user}

The service is being restarted. New tasks will be deployed gradually.
Check status in a few minutes with:
`/ecs-status cluster={cluster} service={service}`
"""}
        
    except Exception as e:
        return {"error": f"Error restarting service: {str(e)}"}

def lambda_handler(event, context):
    """Main Lambda handler"""
    
    print(f"Received event from Slack")
    
    # Verify Slack signature
    if not verify_slack_signature(event):
        return {
            'statusCode': 401,
            'body': json.dumps({'error': 'Invalid signature'})
        }
    
    # Parse body
    body = parse_qs(event.get('body', ''))
    text = body.get('text', [''])[0].strip()
    user_name = body.get('user_name', ['unknown'])[0]
    
    print(f"Command received from {user_name}: {text}")
    
    # Help command
    if text.lower() in ['help', '']:
        help_text = """**ECS Management Commands**

**View Service Status:**
`/ecs-status cluster=<cluster-name> service=<service-name>`

**Restart Service:**
`/ecs-status cluster=<cluster-name> service=<service-name> action=restart`

**Examples:**
• `/ecs-status cluster=my-demo-app-cluster service=my-demo-app-service`
• `/ecs-status cluster=production service=api-service action=restart`

**Parameters:**
• `cluster` - ECS cluster name (required)
• `service` - ECS service name (required)
• `action` - Action to perform: status (default) or restart

**Help:**
`/ecs-status help`
"""
        return {
            'statusCode': 200,
            'body': json.dumps({
                'response_type': 'ephemeral',
                'text': help_text
            })
        }
    
    # Parse parameters
    params = parse_parameters(text)
    
    cluster = params.get('cluster')
    service = params.get('service')
    action = params.get('action', 'status')
    
    # Validate parameters
    if not cluster or not service:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'response_type': 'ephemeral',
                'text': f"""Missing required parameters!

Usage: `/ecs-status cluster=<name> service=<name> action=<status|restart>`

Example: `/ecs-status cluster=my-demo-app-cluster service=my-demo-app-service`
"""
            })
        }
    
    # Execute action
    if action.lower() == 'restart':
        result = restart_service(cluster, service, user_name)
    else:
        result = get_service_status(cluster, service)
    
    # Return response
    if 'error' in result:
        response_text = f"❌ **Error:** {result['error']}"
    else:
        response_text = result['status']
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'response_type': 'ephemeral',
            'text': response_text
        })
    }
