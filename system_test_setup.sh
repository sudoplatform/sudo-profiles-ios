#!/bin/sh

while getopts 'c:p:' c
do
  case $c in
    c) CONFIG_NAME=$OPTARG ;;
  esac
done

if [ -z "$CONFIG_NAME" ]; then
  echo "Usage: sh $0 -c <config_name>"
  exit 1
fi

mkdir -p identity-system-test-config

aws ssm get-parameters --with-decryption --names /platform/identity/private/${CONFIG_NAME}/test-register/register-key > identity-system-test-config/anonyome_ssm_parameter_register_key.json
aws ssm get-parameters --with-decryption --names /platform/identity/public/${CONFIG_NAME}/test-register/register-key > identity-system-test-config/anonyome_ssm_parameter_register_public_key.json
aws ssm get-parameters --with-decryption --names /platform/public/${CONFIG_NAME}/client-config | jq -r '.[] | .[] | .Value' > identity-system-test-config/config.json