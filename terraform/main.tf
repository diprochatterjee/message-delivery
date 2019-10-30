resource "aws_lambda_function" "message_delivery" {
  function_name = "message-delivery"
  s3_bucket     = "lambda-artifacts-dipro-ireland"
  s3_key        = "functions-${var.version}.zip"
  handler       = "functions/index.handler"
  runtime       = "nodejs10.x"

  role       = "${aws_iam_role.lambda_exec.arn}"
  depends_on = ["aws_iam_role_policy_attachment.lambda_logs", "aws_cloudwatch_log_group.message_delivery"]

  environment {
    variables = {
      NODE_ENV      = "production"
      SNS_TOPIC_ARN = "${aws_sns_topic.user_updates.arn}"
      USER_UPDATES_TABLE = "${aws_dynamodb_table.user_updates.id}"
      RECIPIENT_NUMBER = "${var.user_number}"
    }
  }
}

resource "aws_api_gateway_rest_api" "message_delivery" {
  name        = "message_delivery"
  description = "API Gateway for delivering messages to customers"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.message_delivery.id}"
  parent_id   = "${aws_api_gateway_rest_api.message_delivery.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.message_delivery.id}"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.message_delivery.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.message_delivery.invoke_arn}"
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.message_delivery.id}"
  resource_id   = "${aws_api_gateway_rest_api.message_delivery.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.message_delivery.id}"
  resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.message_delivery.invoke_arn}"
}

resource "aws_api_gateway_deployment" "message_delivery" {
  depends_on = [
    "aws_api_gateway_integration.lambda",
    "aws_api_gateway_integration.lambda_root",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.message_delivery.id}"
  stage_name  = "sandbox"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.message_delivery.function_name}"
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.message_delivery.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "message_delivery" {
  name              = "/aws/lambda/message-delivery"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_publish_sns" {
  name        = "lambda_publish_sns"
  path        = "/"
  description = "IAM policy for lambda to publish messages to sns topic"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
    "Action" : [
        "sns:Publish",
        "sns:Subscribe"
    ],
    "Effect" : "Allow",
    "Resource" : "${aws_sns_topic.user_updates.arn}"
}
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.lambda_exec.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_publish_sns" {
  role       = "${aws_iam_role.lambda_exec.name}"
  policy_arn = "${aws_iam_policy.lambda_publish_sns.arn}"
}

resource "aws_sns_topic" "user_updates" {
  name = "user-updates-topic"
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = "${aws_sns_topic.user_updates.arn}"
  protocol  = "sms"
  endpoint  = "${var.user_number}"
}

resource "aws_dynamodb_table" "user_updates" {
  name      = "message-delivery"
  hash_key  = "recipientNumber"
  range_key = "messageId"

  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "recipientNumber"
    type = "S"
  }

  attribute {
    name = "messageId"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_iam_policy" "lambda_dynamo" {
  name        = "lambda_dynamo"
  path        = "/"
  description = "IAM policy for lambda to read and write messages to/from dynamo"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
    "Action" : [
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
    "Effect" : "Allow",
    "Resource" : "${aws_dynamodb_table.user_updates.arn}"
  }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = "${aws_iam_role.lambda_exec.name}"
  policy_arn = "${aws_iam_policy.lambda_dynamo.arn}"
}

resource "aws_api_gateway_api_key" "message_delivery_key" {
  name = "message_delivery_key"
}
resource "aws_api_gateway_usage_plan" "message_delivery_demo" {
  name         = "message_delivery_demo"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.message_delivery.id}"
    stage  = "${aws_api_gateway_deployment.message_delivery.stage_name}"
  }

  quota_settings {
    limit  = 20
    offset = 2
    period = "WEEK"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}
resource "aws_api_gateway_usage_plan_key" "message_delivery_key" {
  key_id        = "${aws_api_gateway_api_key.message_delivery_key.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.message_delivery_demo.id}"
}
