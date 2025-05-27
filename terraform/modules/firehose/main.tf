# Kinesis Data Firehose Configuration
resource "aws_kinesis_firehose_delivery_stream" "delivery_stream" {
  name        = var.name
  destination = var.destination

  kinesis_source_configuration {
    kinesis_stream_arn = var.kinesis_stream_arn
    role_arn           = var.kinesis_role_arn
  }

  extended_s3_configuration {
    role_arn   = var.s3_role_arn
    bucket_arn = var.s3_bucket_arn

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.cdc-transform-function.arn}:$LATEST"
        }
      }
    }
  }
}
