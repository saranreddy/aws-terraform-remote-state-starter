#!/bin/bash
set -e

echo "========================================"
echo "AWS Terraform Remote State - Doctor"
echo "========================================"
echo ""

FAILED=0

# Allow AWS CLI override
AWS_CMD="${AWS_CLI:-aws}"

# Check Terraform
echo "Checking Terraform..."
if command -v terraform &>/dev/null; then
    # Try multiple parsing methods for robustness
    TF_VERSION=""
    
    # Method 1: Try terraform version -json with python3
    if command -v python3 &>/dev/null; then
        TF_VERSION=$(terraform version -json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('terraform_version', ''))" 2>/dev/null || echo "")
    fi
    
    # Method 2: Fall back to plain terraform version output
    if [ -z "$TF_VERSION" ]; then
        TF_VERSION=$(terraform version 2>/dev/null | head -1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//' || echo "")
    fi
    
    # Method 3: Try simple awk parsing
    if [ -z "$TF_VERSION" ]; then
        TF_VERSION=$(terraform version 2>/dev/null | head -1 | awk '{print $2}' | sed 's/v//' || echo "")
    fi
    
    if [ -n "$TF_VERSION" ]; then
        echo "✅ Terraform installed: $TF_VERSION"
    else
        echo "✅ Terraform installed (version detection failed, but command works)"
    fi
else
    echo "❌ Terraform not found"
    echo "   Install: https://www.terraform.io/downloads"
    FAILED=1
fi

echo ""

# Check AWS CLI with actual execution
echo "Checking AWS CLI..."
if command -v "$AWS_CMD" &>/dev/null; then
    # Try to actually execute aws --version
    if AWS_VERSION=$("$AWS_CMD" --version 2>&1); then
        echo "✅ AWS CLI installed: $(echo "$AWS_VERSION" | head -1)"
    else
        echo "❌ AWS CLI found but execution failed"
        echo "   Error: $AWS_VERSION"
        echo ""
        echo "   This often happens with architecture mismatches (e.g., x86_64 binary on arm64 Mac)."
        echo "   Solutions:"
        echo "     - Reinstall AWS CLI v2 for your architecture: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        echo "     - Or use Python awscli: pip3 install awscli && export AWS_CLI='python3 -m awscli'"
        echo "     - Or set AWS_CLI override: export AWS_CLI='python3 -m awscli' && make doctor"
        FAILED=1
    fi
else
    echo "❌ AWS CLI not found (looking for: $AWS_CMD)"
    echo "   Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    echo "   Or: pip3 install awscli"
    FAILED=1
fi

echo ""

# Check AWS credentials with actual execution
echo "Checking AWS credentials..."
if [ $FAILED -eq 0 ]; then
    if CALLER_IDENTITY=$("$AWS_CMD" sts get-caller-identity 2>&1); then
        CALLER_ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4 || echo "$CALLER_IDENTITY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('Arn', 'Unknown'))" 2>/dev/null || echo "Unknown")
        echo "✅ AWS credentials valid"
        echo "   Identity: $CALLER_ARN"
    else
        echo "❌ AWS credentials not configured or invalid"
        echo "   Error: $(echo "$CALLER_IDENTITY" | head -3)"
        echo "   Run: $AWS_CMD configure"
        FAILED=1
    fi
else
    echo "⚠️  Skipped (AWS CLI not working)"
fi

echo ""

# Check AWS region
echo "Checking AWS region..."
if [ $FAILED -eq 0 ]; then
    if AWS_REGION=$("$AWS_CMD" configure get region 2>/dev/null); then
        if [ -n "$AWS_REGION" ]; then
            echo "✅ AWS region configured: $AWS_REGION"
        else
            echo "⚠️  No default region set in AWS CLI config"
            echo "   Set region: $AWS_CMD configure set region us-east-1"
            echo "   Or: export AWS_DEFAULT_REGION=us-east-1"
        fi
    else
        echo "⚠️  Could not read AWS region configuration"
    fi
else
    echo "⚠️  Skipped (AWS CLI not working)"
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
    BUCKET_NAME=""
    if command -v python3 &>/dev/null; then
        BUCKET_NAME=$(python3 -c "import sys, json; print(json.load(open('bootstrap/terraform.tfstate')).get('outputs', {}).get('state_bucket_name', {}).get('value', ''))" 2>/dev/null || echo "")
    fi
    
    if [ -z "$BUCKET_NAME" ] && command -v grep &>/dev/null; then
        BUCKET_NAME=$(grep -A 2 '"state_bucket_name"' bootstrap/terraform.tfstate 2>/dev/null | grep '"value"' | cut -d'"' -f4 || echo "")
    fi
    
    if [ -n "$BUCKET_NAME" ]; then
        echo "   State bucket: $BUCKET_NAME"
        
        # Check if bucket exists (only if AWS CLI is working)
        if [ $FAILED -eq 0 ]; then
            if "$AWS_CMD" s3 ls "s3://$BUCKET_NAME" &>/dev/null; then
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
