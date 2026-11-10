#!/usr/bin/env bash
# Creates the scene: the bucket, and the old user whose access key "leaked". Run once: ./setup.sh
set -u
cd "$(dirname "$0")"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { echo "No working AWS credentials (aws sts get-caller-identity fails)." >&2; exit 1; }
B="clippy-iamlab-$ACCOUNT"
if aws s3api head-bucket --bucket "$B" >/dev/null 2>&1; then echo "Bucket $B already exists. Nothing to do."; exit 0; fi
aws s3api create-bucket --bucket "$B" --region us-east-1 >/dev/null || exit 1
aws s3api put-public-access-block --bucket "$B" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-tagging --bucket "$B" --tagging 'TagSet=[{Key=lab,Value=aws-iam-roles-sts}]'
T=$(mktemp); printf 'internal only: customer list\n' > "$T"
aws s3api put-object --bucket "$B" --key private/customers.txt --body "$T" >/dev/null; rm -f "$T"
aws iam create-user --user-name clippy-export-legacy --tags Key=lab,Value=aws-iam-roles-sts >/dev/null
aws iam put-user-policy --user-name clippy-export-legacy --policy-name legacy-s3 --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:*\",\"Resource\":[\"arn:aws:s3:::$B\",\"arn:aws:s3:::$B/*\"]}]}"
KEY=$(aws iam create-access-key --user-name clippy-export-legacy --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' $(echo "$KEY") > .legacy-key.env
chmod 600 .legacy-key.env
echo "Created s3://$B and the user clippy-export-legacy."
echo "Its access key is in .legacy-key.env (gitignored). That is the key the contractor committed a year ago."
