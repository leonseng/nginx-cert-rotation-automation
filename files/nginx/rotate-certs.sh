#! /usr/bin/env bash

set -e

# Fetch a list of secrets of interest. Using filter to find secrets with certain tags as AWS Secrets Manager does not support multi-tenancy
secrets=$(aws secretsmanager list-secrets --filters "Key=tag-key,Values=nginx-cert-rotation" | jq -r '[.SecretList[].Name]|join(" ")')
echo "Found $secrets"

# Loop through each secret name, fetch the the key pair values and store them locally in /etc/nginx/certs
for secret_id in $secrets; do
  echo "Processing $secret_id";

  # certificate public key is stored in the cert_b64 key, base64 encoded
  aws secretsmanager get-secret-value --secret-id "$secret_id" | jq -r .SecretString | jq -r .cert_b64 | base64 -d > "/etc/nginx/certs/$secret_id.crt";

# certificate public key is stored in the key_b64 key, base64 encoded
  aws secretsmanager get-secret-value --secret-id "$secret_id" | jq -r .SecretString | jq -r .key_b64 | base64 -d > "/etc/nginx/certs/$secret_id.key";

  echo "Success";
done

# reload nginx if is running
systemctl is-active --quiet nginx.service && nginx -s reload || true
