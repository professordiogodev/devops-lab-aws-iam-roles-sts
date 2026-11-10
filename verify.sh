#!/usr/bin/env bash
# Assumes your role and tests what it can and cannot do. Run with: ./verify.sh
cd "$(dirname "$0")" || exit 1
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { echo "No working AWS credentials." >&2; exit 1; }
exec python3 .lab/awscheck.py "$ACCOUNT"
