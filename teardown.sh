#!/usr/bin/env bash
# Deletes the role, the legacy user and the bucket. Run with: ./teardown.sh
set -u
cd "$(dirname "$0")"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { echo "No working AWS credentials." >&2; exit 1; }
B="clippy-iamlab-$ACCOUNT"
for r in clippy-export-writer; do
  if aws iam get-role --role-name $r >/dev/null 2>&1; then
    for p in $(aws iam list-role-policies --role-name $r --query PolicyNames --output text); do aws iam delete-role-policy --role-name $r --policy-name "$p"; done
    for a in $(aws iam list-attached-role-policies --role-name $r --query 'AttachedPolicies[].PolicyArn' --output text); do aws iam detach-role-policy --role-name $r --policy-arn "$a"; case "$a" in arn:aws:iam::aws:*) ;; *) aws iam delete-policy --policy-arn "$a" 2>/dev/null;; esac; done
    aws iam delete-role --role-name $r && echo "deleted role $r"
  fi
done
u=clippy-export-legacy
if aws iam get-user --user-name $u >/dev/null 2>&1; then
  for k in $(aws iam list-access-keys --user-name $u --query 'AccessKeyMetadata[].AccessKeyId' --output text); do aws iam delete-access-key --user-name $u --access-key-id "$k"; done
  for p in $(aws iam list-user-policies --user-name $u --query PolicyNames --output text); do aws iam delete-user-policy --user-name $u --policy-name "$p"; done
  aws iam delete-user --user-name $u && echo "deleted user $u"
fi
for p in $(aws iam list-policies --scope Local --query "Policies[?starts_with(PolicyName, 'clippy-export')].Arn" --output text); do aws iam delete-policy --policy-arn "$p" 2>/dev/null && echo "deleted policy $p"; done
if aws s3api head-bucket --bucket "$B" >/dev/null 2>&1; then
  aws s3 rm "s3://$B" --recursive >/dev/null && aws s3api delete-bucket --bucket "$B" && echo "deleted s3://$B"
fi
rm -f .legacy-key.env
echo "Now run ./verify-teardown.sh"
