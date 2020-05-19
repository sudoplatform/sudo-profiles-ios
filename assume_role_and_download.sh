#!/bin/sh

while getopts 'r:c:a:l:' c
do
  case $c in
    c) CONFIG_NAME=$OPTARG ;;
    r) ROLE_ARN=$OPTARG ;;
    a) ACCOUNT_ID=$OPTARG ;;
    l) REGION=$OPTARG ;;
  esac
done

if [ -z "$CONFIG_NAME" ] || [ -z "$ROLE_ARN" ] || [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ]; then
  echo "Usage: sh $0 -c <config_name> -r <role_arn> -a <account_id> -l <region>" 
  exit 1
fi


echo "Switching account '${ACCOUNT_ID}' to role '${ROLE_ARN}' in '${REGION}' for config '${CONFIG_NAME}'."
AWS_DEFAULT_REGION=${REGION}
export AWS_DEFAULT_REGION
SESSION_NAME="${ACCOUNT_ID}-${REGION}-${CONFIG_NAME}"
CREDS=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME" --out json) \
    || exit 1
AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
export AWS_SESSION_TOKEN

sh ./system_test_setup.sh -c ${CONFIG_NAME}