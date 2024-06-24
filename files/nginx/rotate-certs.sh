#! /usr/bin/env bash

set -e

secrets=$(aws secretsmanager list-secrets --filters "Key=tag-key,Values=${secrets_manager_target_tag}" | jq -r '[.SecretList[].Name]|join(" ")')
echo "Found $secrets"

# Loop through each secret name and echo it
for secret_id in $secrets; do
  echo "Processing $secret_id";
  aws secretsmanager get-secret-value --secret-id "$secret_id" | jq -r .SecretString | jq -r .cert_b64 | base64 -d > "/etc/nginx/certs/$secret_id.crt";
  aws secretsmanager get-secret-value --secret-id "$secret_id" | jq -r .SecretString | jq -r .key_b64 | base64 -d > "/etc/nginx/certs/$secret_id.key";
done

# reload nginx if is running
systemctl is-active --quiet nginx.service && nginx -s reload || true
