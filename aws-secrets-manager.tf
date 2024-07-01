resource "tls_private_key" "test" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "test" {
  private_key_pem = tls_private_key.test.private_key_pem

  subject {
    common_name  = local.test_server_name
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_secretsmanager_secret" "cert_key_pair" {
  name = local.name_prefix

  tags = {
    "${var.secrets_manager_target_tag}" = ""
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.cert_key_pair.id
  secret_string = jsonencode({
    key_b64  = base64encode(tls_private_key.test.private_key_pem)
    cert_b64 = base64encode(tls_self_signed_cert.test.cert_pem)
  })
}
