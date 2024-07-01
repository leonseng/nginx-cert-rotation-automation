# Note event fired by AWS services always goes to default event bus
# https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-service-event.html
resource "aws_cloudwatch_event_rule" "update" {
  depends_on = [aws_secretsmanager_secret_version.this]

  name          = local.name_prefix
  description   = "Forwards updates to certs in AWS Secret Manager to AWS Lambda"
  event_pattern = <<EOT
{
  "source": ["aws.secretsmanager"],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": ["secretsmanager.amazonaws.com"],
    "eventName": ["CreateSecret", "PutSecretValue", "UpdateSecret"]
  }
}
EOT

}

resource "aws_lambda_permission" "allow_eventbridge" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_nginx.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.update.arn
}

resource "aws_cloudwatch_event_target" "to_lambda" {
  rule = aws_cloudwatch_event_rule.update.name
  arn  = aws_lambda_function.update_nginx.arn
}
