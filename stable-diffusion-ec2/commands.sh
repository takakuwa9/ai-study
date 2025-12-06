#!/bin/bash
# Common AWS CLI Commands for Stable Diffusion Stack
# Copy and paste individual commands as needed

STACK_NAME="stable-diffusion-stack"

# ============================================
# STACK MANAGEMENT
# ============================================

# View stack status
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].StackStatus'

# View stack events (latest 10)
aws cloudformation describe-stack-events \
  --stack-name "$STACK_NAME" \
  --query 'StackEvents[0:10]' \
  --output table

# View all stack outputs
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table

# View specific output value
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
  --output text

# List all resources in stack
aws cloudformation list-stack-resources \
  --stack-name "$STACK_NAME" \
  --output table

# ============================================
# EC2 INSTANCE MANAGEMENT
# ============================================

# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:cloudformation:stack-name,Values=$STACK_NAME" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Public IP: $PUBLIC_IP"

# Check instance status
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,InstanceType]' \
  --output table

# View instance details
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --output json | jq '.Reservations[0].Instances[0]'

# Start instance (if stopped)
aws ec2 start-instances --instance-ids "$INSTANCE_ID"

# Stop instance
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"

# Reboot instance
aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"

# Get console output (useful for debugging)
aws ec2 get-console-output --instance-id "$INSTANCE_ID"

# ============================================
# S3 BUCKET MANAGEMENT
# ============================================

# Get S3 bucket name
S3_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

echo "S3 Bucket: $S3_BUCKET"

# List S3 bucket contents
aws s3 ls s3://"$S3_BUCKET"/ --recursive

# List only results folder
aws s3 ls s3://"$S3_BUCKET"/results/ --recursive

# Download result image from S3
aws s3 cp s3://"$S3_BUCKET"/results/your-image-id.png ./downloaded-image.png

# Delete specific file from S3
aws s3 rm s3://"$S3_BUCKET"/results/image-id.png

# Empty S3 bucket (before deleting stack)
aws s3 rm s3://"$S3_BUCKET" --recursive

# View S3 bucket properties
aws s3api head-bucket --bucket "$S3_BUCKET"

# ============================================
# MONITORING & LOGS
# ============================================

# Monitor stack creation (watch status)
watch -n 5 'aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].[StackName,StackStatus,StackStatusReason]" \
  --output table'

# Get latest CloudWatch logs
aws logs tail /aws/ec2/stable-diffusion --follow

# View system metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# ============================================
# SSH CONNECTIONS
# ============================================

# SSH into instance
ssh -i stable-diffusion-key.pem ubuntu@"$PUBLIC_IP"

# SSH with port forwarding (to access API locally)
ssh -i stable-diffusion-key.pem \
  -L 8000:localhost:8000 \
  ubuntu@"$PUBLIC_IP"
# Then access: curl http://localhost:8000/health

# SCP to download files from instance
scp -i stable-diffusion-key.pem \
  ubuntu@"$PUBLIC_IP":/opt/stable-diffusion/setup-complete.txt \
  ./

# SCP to upload files to instance
scp -i stable-diffusion-key.pem \
  ./myfile.txt \
  ubuntu@"$PUBLIC_IP":/opt/stable-diffusion/

# ============================================
# SECURITY & ACCESS
# ============================================

# View security group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=StableDiffusionSG*" \
  --output table

# Add SSH access from your IP
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 authorize-security-group-ingress \
  --group-name "StableDiffusionSG*" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_IP"

# Revoke SSH access from 0.0.0.0/0 (after adding your IP)
aws ec2 revoke-security-group-ingress \
  --group-name "StableDiffusionSG*" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# ============================================
# COST ESTIMATION
# ============================================

# Get spot price history (last hour)
aws ec2 describe-spot-price-history \
  --instance-types g4dn.xlarge \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --product-descriptions "Linux/UNIX" \
  --output table

# Calculate estimated monthly cost (example: g4dn.xlarge at $0.20/hr)
# Usage: 24 hrs/day * 30 days * $0.20/hr = $144/month
echo "Estimated monthly cost (g4dn.xlarge @ $0.20/hr):"
echo "scale=2; 24 * 30 * 0.20" | bc

# ============================================
# CLEANUP & DELETION
# ============================================

# List all resources before deletion
aws cloudformation list-stack-resources --stack-name "$STACK_NAME" --output table

# Delete the entire stack (delete CloudFormation first)
aws cloudformation delete-stack --stack-name "$STACK_NAME"

# Wait for stack deletion
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"

# Verify deletion
aws cloudformation list-stacks \
  --query "StackSummaries[?StackName=='$STACK_NAME']"

# ============================================
# BATCH OPERATIONS EXAMPLES
# ============================================

# Generate batch predictions using AWS Batch (advanced)
# This requires additional setup for SQS + Lambda

# Create SQS queue for job submissions
aws sqs create-queue --queue-name stable-diffusion-jobs

# Send image generation job to SQS
aws sqs send-message \
  --queue-url https://sqs.region.amazonaws.com/account/stable-diffusion-jobs \
  --message-body '{
    "prompt": "a beautiful landscape",
    "steps": 50,
    "guidance": 7.5
  }'

# ============================================
# DEBUGGING TIPS
# ============================================

# Check CloudFormation template syntax
aws cloudformation validate-template --template-body file://template.yaml

# Get all parameters used in stack
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Parameters' \
  --output table

# Export all outputs to environment variables
eval $(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
  --output text | awk '{print "export "$1"=\""$2"\""}')

echo "Exported variables:"
echo "InstanceId: $InstanceId"
echo "PublicIP: $PublicIP"
echo "S3BucketName: $S3BucketName"

# ============================================
# ADVANCED: Update Stack
# ============================================

# Update stack with new parameters (without template)
aws cloudformation update-stack \
  --stack-name "$STACK_NAME" \
  --use-previous-template \
  --parameters \
    ParameterKey=ModelName,ParameterValue=stabilityai/stable-diffusion-2-1 \
    UsePreviousValue=true

# Update stack with new template
aws cloudformation update-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://template.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
