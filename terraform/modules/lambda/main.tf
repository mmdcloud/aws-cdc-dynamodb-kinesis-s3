# Lambda function configuration
resource "aws_lambda_function" "function" {
  filename      = var.filename
  function_name = var.function_name
  role          = var.role
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  tags = {
    Name = var.function_name
  }
}