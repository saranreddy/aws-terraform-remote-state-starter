#!/bin/bash
set -e

echo "========================================"
echo "AWS Terraform Remote State - Doctor"
echo "========================================"
echo ""

FAILED=0

# Check Terraform
echo "Checking Terraform..."
if command -v terraform &>/dev/null; then
    TF_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1 | awk '{print $2}' | sed 's/v//')
    echo "✅ Terraform installed: $TF_VERSION"
else
    echo "❌ Terraform not found"
    echo "   Install: https://www.terraform.io/downloads"
    FAILED=1
fi

echo ""

# Check AWS CLI
echo "Checking AWS CLI..."
if command -v aws &>/dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}')
    echo "✅ AWS CLI installed: $AWS_VERSION"
else
    echo "❌ AWS CLI not found"
    echo "   Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    FAILED=1
fi

echo ""

# Check AWS credentials
echo "Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
    CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
    echo "✅ AWS credentials valid"
    echo "   Identity: $CALLER_ARN"
else
    echo "❌ AWS credentials not configured or invalid"
    echo "   Run: aws configure"
    FAILED=1
fi

echo ""

# Check AWS region
echo "Checking AWS region..."
if AWS_REGION=$(aws configure get region 2>/dev/null); then
    if [ -n "$AWS_REGION" ]; then
        echo "✅ AWS region configured: $AWS_REGION"
    else
        echo "⚠️  No default region set in AWS CLI config"
        echo "   Set region: aws configure set region us-east-1"
        echo "   Or: export AWS_DEFAULT_REGION=us-east-1"
    fi
else
    echo "⚠️  No AWS region configured"
fi

echo ""

# Check for make (optional but recommended)
echo "Checking make (optional)..."
if command -v make &>/dev/null; then
    MAKE_VERSION=$(make --version 2>/dev/null | head -1)
    echo "✅ make installed: $MAKE_VERSION"
else
    echo "⚠️  make not found (optional, but Makefile targets won't work)"
    echo "   You can still use raw Terraform commands"
fi

echo ""

# Check bootstrap state
echo "Checking bootstrap state..."
if [ -f bootstrap/terraform.tfstate ]; then
    echo "✅ Bootstrap state file exists (bootstrap/terraform.tfstate)"
    
    # Try to extract bucket name from state
    if command -v jq &>/dev/null; then
        BUCKET_NAME=$(jq -r '.outputs.state_bucket_name.value // empty' bootstrap/terraform.tfstate 2>/dev/null)
        if [ -n "$BUCKET_NAME" ]; then
            echo "   State bucket: $BUCKET_NAME"
            
            # Check if bucket exists
            if aws s3 ls "s3://$BUCKET_NAME" &>/dev/null; then
                echo "   ✅ State bucket exists and is accessible"
            else
                echo "   ⚠️  State bucket not accessible (may need credentials or doesn't exist)"
            fi
        fi
    fi
else
    echo "⚠️  Bootstrap not applied yet (no terraform.tfstate in bootstrap/)"
    echo "   Run: make bootstrap"
fi

echo ""
echo "========================================"

if [ $FAILED -eq 1 ]; then
    echo "❌ Prerequisites check FAILED"
    echo "   Fix the issues above and run again"
    exit 1
else
    echo "✅ All checks passed!"
    echo "========================================"
    exit 0
fi
