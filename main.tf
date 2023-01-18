# Generate resource group
resource "aws_resourcegroups_group" "rg" {
  name        = var.resource_group_name
  description = "Resource Group for ${var.resource_tags.use_case}"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "use_case",
          "Values": [
            "${var.resource_tags.use_case}"
          ]
        }
      ]
    }
    JSON
  }

  tags = var.resource_tags
}

# Create s3 bucket
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${lower(random_string.prefix.result)}-bucket"

  tags = var.resource_tags
}

# Set s3 bucket acl
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

# Store code to variable
data "template_file" "hello" {
  template = file("${path.module}/external/lambda/hello.js")
}

# Convert code to zip file
data "archive_file" "hello" {
  type = "zip"
  output_path = "${path.module}/external/lambda/hello.zip"

  source {
    content  = data.template_file.hello.rendered
    filename = "hello.js"
  }
}

# Upload lambda to s3 bucket
resource "aws_s3_object" "lambda" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "hello.zip"
  source = data.archive_file.hello.output_path
  etag = filemd5(data.archive_file.hello.output_path)

  tags = var.resource_tags
}

# Create iam role for lambda
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })

  tags = var.resource_tags
}

# Set role policy to allow execution of lambda
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create lambda and attach iam role
resource "aws_lambda_function" "lambda" {
  function_name = "hello"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda.key

  runtime = "nodejs16.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.hello.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  tags = var.resource_tags
}

# Create cloudwatch log group for lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${aws_lambda_function.lambda.function_name}"

  retention_in_days = 30

  tags = var.resource_tags
}

# Create api gateway v2
resource "aws_apigatewayv2_api" "lambda" {
  name          = "${random_string.prefix.result}-apigw"
  protocol_type = "HTTP"

  tags = var.resource_tags
}

# Create api gateway v2 stage
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "${random_string.prefix.result}-stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.lambda.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }

  tags = var.resource_tags
}

# Create api gateway v2 integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Create api gateway v2 route
resource "aws_apigatewayv2_route" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Create cloudwatch log group for api gw
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30

  tags = var.resource_tags
}

# Set lambda permission
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
