data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ssh_access" {
  public_key = var.ssh_public_key
}

resource "aws_security_group" "nginx" {
  description = "Security group for SSH and Lambda access"
  vpc_id      = aws_vpc.this.id

  # Inbound rule to allow SSH from anywhere
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
  }

  ingress {
    description     = "Allow Lambda access to port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Outbound rules to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example_sg"
  }
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nginx" {
  name               = "${local.name_prefix}-nginx"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json

  inline_policy {
    name   = "get-secrets"
    policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "secretsmanager:ListSecrets",
            "secretsmanager:GetSecretValue"
          ],
          "Resource": "*"
        }
    ]
}
EOT
  }
}

resource "aws_iam_instance_profile" "nginx" {
  name = "${local.name_prefix}-nginx"
  role = aws_iam_role.nginx.id
}

resource "aws_instance" "nginx" {
  count = var.aws_az_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ssh_access.key_name
  subnet_id     = aws_subnet.this[count.index].id
  user_data = templatefile("${path.module}/files/nginx/cloud-init.yaml", {
    nginx_conf = base64encode(file("${path.module}/files/nginx/nginx.conf"))
    rotate_certs_sh = base64encode(
      templatefile(
        "${path.module}/files/nginx/rotate-certs.sh",
        { secrets_manager_target_tag : var.secrets_manager_target_tag }
      )
    )
    lambda_listener_py = base64encode(file("${path.module}/files/nginx/lambda-listener.py"))
  })

  iam_instance_profile = aws_iam_instance_profile.nginx.id

  vpc_security_group_ids = [
    aws_security_group.nginx.id
  ]

  tags = {
    Name                          = "${local.name_prefix}-nginx-${count.index + 1}"
    "${var.nginx_ec2_target_tag}" = ""
  }
}
