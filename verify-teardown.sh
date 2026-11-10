#!/usr/bin/env bash
# Proves the lab left nothing in AWS. Run with: ./verify-teardown.sh
set -u
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { echo "No working AWS credentials." >&2; exit 1; }
echo "Checking account $ACCOUNT"
pass=0; failn=0
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
check "no role clippy-export-writer" bash -c "! aws iam get-role --role-name clippy-export-writer"
check "no user clippy-export-legacy (and so no leaked key)" bash -c "! aws iam get-user --user-name clippy-export-legacy"
check "no customer managed policy named clippy-export*" bash -c "[ -z \"\$(aws iam list-policies --scope Local --query \"Policies[?starts_with(PolicyName, 'clippy-export')].PolicyName\" --output text)\" ]"
check "the bucket clippy-iamlab-$ACCOUNT is gone" bash -c "! aws s3api head-bucket --bucket clippy-iamlab-$ACCOUNT"
check "no .legacy-key.env file left" bash -c "! test -e .legacy-key.env"
echo
if [ "$failn" -eq 0 ]; then echo "TEARDOWN VERIFIED ($pass/$pass) in account $ACCOUNT"; else echo "NOT CLEAN: $failn leftover(s). Remove them and run this again."; fi
exit "$failn"
