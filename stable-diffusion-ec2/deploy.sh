#!/bin/bash

# Stable Diffusion EC2 Spot Instance - Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Stable Diffusion EC2 Spot Deployment${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Get AWS account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo -e "${GREEN}✓ AWS CLI configured${NC}"
echo -e "  Account ID: $ACCOUNT_ID"
echo -e "  Region: $REGION\n"

# Prompt for parameters
echo -e "${YELLOW}=== Configuration ===${NC}"

read -p "EC2 Key Pair Name (e.g., stable-diffusion-key): " KEY_PAIR_NAME
if [ -z "$KEY_PAIR_NAME" ]; then
    echo -e "${RED}Error: Key pair name is required${NC}"
    exit 1
fi

read -p "Instance Type (default: g4dn.xlarge): " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-g4dn.xlarge}

read -p "Spot Max Price USD/hour (default: 0.50): " SPOT_MAX_PRICE
SPOT_MAX_PRICE=${SPOT_MAX_PRICE:-0.50}

read -p "Model Name (default: runwayml/stable-diffusion-v1-5): " MODEL_NAME
MODEL_NAME=${MODEL_NAME:-runwayml/stable-diffusion-v1-5}

read -p "Allowed SSH CIDR (default: 0.0.0.0/0, restrict in production): " ALLOWED_SSH_CIDR
ALLOWED_SSH_CIDR=${ALLOWED_SSH_CIDR:-0.0.0.0/0}

read -p "EBS Volume Size in GB (default: 100): " EBS_VOLUME_SIZE
EBS_VOLUME_SIZE=${EBS_VOLUME_SIZE:-100}

STACK_NAME="stable-diffusion-stack"

echo -e "\n${YELLOW}=== Summary ===${NC}"
echo "Stack Name: $STACK_NAME"
echo "Key Pair: $KEY_PAIR_NAME"
echo "Instance Type: $INSTANCE_TYPE"
echo "Spot Max Price: \$$SPOT_MAX_PRICE/hour"
echo "Model: $MODEL_NAME"
echo "SSH CIDR: $ALLOWED_SSH_CIDR"
echo "EBS Volume: ${EBS_VOLUME_SIZE}GB"
echo ""

read -p "Proceed with deployment? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

# Check if template exists
if [ ! -f "template.yaml" ]; then
    echo -e "${RED}Error: template.yaml not found in current directory${NC}"
    exit 1
fi

echo -e "\n${BLUE}Creating CloudFormation stack...${NC}"

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://template.yaml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue="$KEY_PAIR_NAME" \
    ParameterKey=InstanceType,ParameterValue="$INSTANCE_TYPE" \
    ParameterKey=SpotMaxPrice,ParameterValue="$SPOT_MAX_PRICE" \
    ParameterKey=ModelName,ParameterValue="$MODEL_NAME" \
    ParameterKey=AllowedSSHCIDR,ParameterValue="$ALLOWED_SSH_CIDR" \
    ParameterKey=EBSVolumeSize,ParameterValue="$EBS_VOLUME_SIZE" \
  --capabilities CAPABILITY_NAMED_IAM

echo -e "${GREEN}✓ Stack creation initiated${NC}"
echo -e "\n${YELLOW}Waiting for stack creation to complete...${NC}"
echo "(This may take 10-15 minutes)"

# Wait for stack creation
aws cloudformation wait stack-create-complete \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

echo -e "${GREEN}✓ Stack created successfully${NC}\n"

# Get outputs
echo -e "${BLUE}=== Stack Outputs ===${NC}"

OUTPUTS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output json)

INSTANCE_ID=$(echo $OUTPUTS | grep -o '"InstanceId"' -A 2 | grep -o 'i-[^"]*')
PUBLIC_IP=$(echo $OUTPUTS | grep -o '"PublicIP"' -A 2 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
API_ENDPOINT=$(echo $OUTPUTS | grep -o '"APIEndpoint"' -A 2 | grep -o 'http://[^"]*')
S3_BUCKET=$(echo $OUTPUTS | grep -o '"S3BucketName"' -A 2 | grep -o 'stable-diffusion-[^"]*')

if [ -n "$INSTANCE_ID" ]; then
    echo "Instance ID: $INSTANCE_ID"
fi
if [ -n "$PUBLIC_IP" ]; then
    echo "Public IP: $PUBLIC_IP"
fi
if [ -n "$API_ENDPOINT" ]; then
    echo "API Endpoint: $API_ENDPOINT"
fi
if [ -n "$S3_BUCKET" ]; then
    echo "S3 Bucket: $S3_BUCKET"
fi

echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo "1. Wait for instance setup (check UserData log):"
if [ -n "$PUBLIC_IP" ]; then
    echo "   ssh -i <your-key.pem> ubuntu@$PUBLIC_IP"
    echo "   tail -f /var/log/user-data.log"
fi

echo ""
echo "2. Check instance status:"
echo "   aws ec2 describe-instances --instance-ids $INSTANCE_ID"

echo ""
echo "3. Test API (after setup completes, ~15-25 min):"
if [ -n "$PUBLIC_IP" ]; then
    echo "   curl http://$PUBLIC_IP:8000/health"
    echo "   curl http://$PUBLIC_IP:8000/docs  (Swagger UI)"
fi

echo ""
echo "4. View CloudFormation stack:"
echo "   aws cloudformation describe-stacks --stack-name $STACK_NAME"

echo ""
echo -e "${YELLOW}=== Cost Management ===${NC}"
echo "To stop the instance:"
echo "  aws ec2 stop-instances --instance-ids $INSTANCE_ID"
echo ""
echo "To delete everything:"
echo "  aws s3 rm s3://$S3_BUCKET --recursive"
echo "  aws cloudformation delete-stack --stack-name $STACK_NAME"

echo ""
echo -e "${GREEN}Deployment script completed!${NC}"
