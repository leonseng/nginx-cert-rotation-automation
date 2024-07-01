data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json

  inline_policy {
    name   = "attach-lambda-to-vpc"
    policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateNetworkInterface",
            "ec2:DeleteNetworkInterface"
          ],
          "Resource": "*"
        }
    ]
}
EOT
  }

  inline_policy {
    name   = "get-ec2-private-ips"
    policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ec2:DescribeInstances"
          ],
          "Resource": "*"
        }
    ]
}
EOT
  }

  inline_policy {
    name   = "log-to-cloudwatch"
    policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Effect": "Allow",
          "Action": "logs:CreateLogGroup",
          "Resource": "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": [
            "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_function_name}:*"
          ]
        }
    ]
}
EOT
  }

}

resource "aws_security_group" "lambda" {
  description = "Lambda outbound access"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "local_file" "foo" {
  content = templatefile(
    "${path.module}/files/lambda/lambda_function.py",
    {
      nginx_ec2_target_tag : var.nginx_ec2_target_tag
    }
  )
  filename = "${path.module}/.tmp/lambda/lambda_function.py"
}

data "archive_file" "lambda" {
  depends_on  = [local_file.foo]
  type        = "zip"
  source_dir  = "${path.module}/.tmp/lambda/"
  output_path = "${path.module}/.tmp/lambda_function_payload.zip"
}

resource "aws_lambda_function" "update_nginx" {
  filename         = "${path.module}/.tmp/lambda_function_payload.zip"
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60

  vpc_config {
    security_group_ids = [aws_security_group.lambda.id]
    subnet_ids         = [aws_subnet.private_lambda.id]
  }
}
