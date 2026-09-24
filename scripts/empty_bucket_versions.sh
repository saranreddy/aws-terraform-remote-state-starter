#!/bin/bash
# Helper script to empty all versions from the state bucket before destroy
# S3 versioned buckets cannot be destroyed until all versions are deleted
# Usage: ./empty_bucket_versions.sh [--yes]

set -e

# Check for non-interactive flag
NON_INTERACTIVE=0
if [ "$1" = "--yes" ] || [ "$FORCE" = "1" ]; then
    NON_INTERACTIVE=1
fi

echo "Checking for state bucket versions to clean up..."

# Extract bucket name from bootstrap state
if [ ! -f bootstrap/terraform.tfstate ]; then
    echo "No bootstrap state found, skipping bucket cleanup"
    exit 0
fi

if command -v jq &>/dev/null; then
    BUCKET_NAME=$(jq -r '.outputs.state_bucket_name.value // empty' bootstrap/terraform.tfstate)
else
    BUCKET_NAME=$(cd bootstrap && terraform output -raw state_bucket_name 2>/dev/null || echo "")
fi

if [ -z "$BUCKET_NAME" ]; then
    echo "Could not extract bucket name from state, skipping"
    exit 0
fi

echo "State bucket: $BUCKET_NAME"

# Check if bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket does not exist or is not accessible, skipping"
    exit 0
fi

# Check if there are any versions
VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)
DELETE_MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)

VERSION_COUNT=$(echo "$VERSIONS" | jq '.Objects // [] | length')
MARKER_COUNT=$(echo "$DELETE_MARKERS" | jq '.Objects // [] | length')

TOTAL=$((VERSION_COUNT + MARKER_COUNT))

if [ "$TOTAL" -eq 0 ]; then
    echo "No versions or delete markers to clean up"
    exit 0
fi

echo ""
echo "⚠️  Found $VERSION_COUNT object versions and $MARKER_COUNT delete markers"
echo ""
echo "⚠️  WARNING: This will permanently delete all versions in the state bucket!"
echo "⚠️  This includes all state history for all environments."
echo ""

if [ "$NON_INTERACTIVE" -eq 0 ]; then
    read -p "Type 'yes' to proceed with deletion: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
else
    echo "Non-interactive mode: proceeding with deletion"
fi

echo ""
echo "Deleting object versions..."

if [ "$VERSION_COUNT" -gt 0 ]; then
    echo "$VERSIONS" | jq -c '.Objects[]' | while read -r obj; do
        KEY=$(echo "$obj" | jq -r '.Key')
        VERSION_ID=$(echo "$obj" | jq -r '.VersionId')
        echo "  Deleting: $KEY (version $VERSION_ID)"
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VERSION_ID" >/dev/null
    done
fi

if [ "$MARKER_COUNT" -gt 0 ]; then
    echo "Deleting delete markers..."
    echo "$DELETE_MARKERS" | jq -c '.Objects[]' | while read -r obj; do
        KEY=$(echo "$obj" | jq -r '.Key')
        VERSION_ID=$(echo "$obj" | jq -r '.VersionId')
        echo "  Deleting marker: $KEY (version $VERSION_ID)"
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VERSION_ID" >/dev/null
    done
fi

echo ""
echo "✅ Bucket cleanup complete"
echo "   You can now run: terraform destroy"
