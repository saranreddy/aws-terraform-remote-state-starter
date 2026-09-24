#!/bin/bash
set -e

echo "========================================"
echo "Smoke Test - Remote State Backend"
echo "========================================"
echo ""

FAILED=0

# Check if bootstrap is applied
echo "Step 1: Checking bootstrap state..."
if [ ! -f bootstrap/terraform.tfstate ]; then
    echo "❌ Bootstrap not applied (no terraform.tfstate in bootstrap/)"
    echo "   Run: make bootstrap"
    exit 1
fi

echo "✅ Bootstrap state exists"
echo ""

# Extract backend config from bootstrap outputs
echo "Step 2: Extracting backend configuration..."

if ! command -v jq &>/dev/null; then
    echo "⚠️  jq not installed, using terraform output commands instead"
    BUCKET_NAME=$(cd bootstrap && terraform output -raw state_bucket_name 2>/dev/null)
    LOCK_TABLE=$(cd bootstrap && terraform output -raw lock_table_name 2>/dev/null)
    AWS_REGION=$(cd bootstrap && terraform output -raw aws_region 2>/dev/null)
else
    BUCKET_NAME=$(jq -r '.outputs.state_bucket_name.value' bootstrap/terraform.tfstate)
    LOCK_TABLE=$(jq -r '.outputs.lock_table_name.value' bootstrap/terraform.tfstate)
    AWS_REGION=$(jq -r '.outputs.aws_region.value' bootstrap/terraform.tfstate)
fi

if [ -z "$BUCKET_NAME" ] || [ -z "$LOCK_TABLE" ]; then
    echo "❌ Could not extract backend config from bootstrap state"
    exit 1
fi

echo "✅ Backend configuration:"
echo "   Bucket: $BUCKET_NAME"
echo "   Lock Table: $LOCK_TABLE"
echo "   Region: $AWS_REGION"
echo ""

# Check S3 bucket exists
echo "Step 3: Checking S3 state bucket..."
if aws s3 ls "s3://$BUCKET_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "✅ S3 bucket exists and is accessible"
    
    # Check bucket versioning
    VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION" --query Status --output text 2>/dev/null || echo "")
    if [ "$VERSIONING" = "Enabled" ]; then
        echo "✅ Bucket versioning enabled"
    else
        echo "⚠️  Bucket versioning not enabled or not readable"
    fi
else
    echo "❌ S3 bucket not accessible"
    FAILED=1
fi

echo ""

# Check DynamoDB lock table exists
echo "Step 4: Checking DynamoDB lock table..."
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" &>/dev/null; then
    echo "✅ DynamoDB lock table exists"
    
    # Check billing mode
    BILLING=$(aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" --query 'Table.BillingModeSummary.BillingMode' --output text 2>/dev/null || echo "")
    if [ "$BILLING" = "PAY_PER_REQUEST" ]; then
        echo "✅ Lock table using on-demand billing"
    else
        echo "⚠️  Lock table billing mode: $BILLING"
    fi
else
    echo "❌ DynamoDB lock table not accessible"
    FAILED=1
fi

echo ""

# Check if any environment is applied
echo "Step 5: Checking environment deployments..."
ENV_FOUND=0

for ENV in dev stage prod; do
    if [ -f "environments/$ENV/terraform.tfstate" ] || aws s3 ls "s3://$BUCKET_NAME/$ENV/terraform.tfstate" --region "$AWS_REGION" &>/dev/null; then
        echo "✅ Environment '$ENV' has state"
        ENV_FOUND=1
        
        # Try to get outputs from that environment
        if [ -d "environments/$ENV/.terraform" ]; then
            echo "   Checking $ENV resources..."
            
            cd "environments/$ENV"
            
            # Check if outputs are available
            if terraform output &>/dev/null; then
                BUCKET=$(terraform output -raw bucket_name 2>/dev/null || echo "")
                SSM_PARAM=$(terraform output -raw ssm_parameter_name 2>/dev/null || echo "")
                
                if [ -n "$BUCKET" ]; then
                    # Verify S3 bucket exists
                    if aws s3 ls "s3://$BUCKET" --region "$AWS_REGION" &>/dev/null; then
                        echo "   ✅ S3 workload bucket exists: $BUCKET"
                    else
                        echo "   ⚠️  S3 workload bucket not found: $BUCKET"
                    fi
                fi
                
                if [ -n "$SSM_PARAM" ]; then
                    # Verify SSM parameter exists
                    if aws ssm get-parameter --name "$SSM_PARAM" --region "$AWS_REGION" &>/dev/null; then
                        echo "   ✅ SSM parameter exists: $SSM_PARAM"
                    else
                        echo "   ⚠️  SSM parameter not found: $SSM_PARAM"
                    fi
                fi
            else
                echo "   ⚠️  No outputs available (may need terraform refresh)"
            fi
            
            cd ../..
        fi
    fi
done

if [ $ENV_FOUND -eq 0 ]; then
    echo "⚠️  No environments deployed yet"
    echo "   Run: make init-dev && make apply-dev"
fi

echo ""
echo "========================================"

if [ $FAILED -eq 1 ]; then
    echo "❌ Smoke test FAILED"
    exit 1
else
    echo "✅ Smoke test PASSED!"
    echo "   Remote state backend is working correctly"
    echo "========================================"
    exit 0
fi
