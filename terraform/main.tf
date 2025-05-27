# S3 bucket for storing processed data
module "s3_bucket" {
  source        = "terraform/modules/s3"
  bucket_name   = "madmaxkinesis-s3-dest"
  force_destroy = true
}

module "cdc_function_role" {
  source             = "terraform/modules/iam"
  role_name          = "cdc_function_role"
  role_description   = "cdc_function_role"
  policy_name        = "cdc_function_iam_policy"
  policy_description = "cdc_function_iam_policy"
  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
    EOF
  policy             = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
       {
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": ["arn:aws:logs:*:*:*"],
          "Effect": "Allow"
       } 
      ]
    }
    EOF
}

# DynamoDB table
module "orders_dynamodb_table" {
  source = "terraform/modules/dynamodb"
  name           = "orders"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "roll_no"
  attributes = [
    {
      name = "roll_no"
      type = "N"
    }
  ]
  ttl_attribute_name = "TimeToExist"
  ttl_enabled        = true
}

module "cdc_transform_function" {
  source        = "terraform/modules/lambda"
  filename      = "lambda.zip"
  function_name = "cdc-transform-function"
  role          = module.cdc_function_role.role_arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.12"
  timeout       = 180
}

# Kinesis Data Stream configuration
module "cdc_kinesis_stream" {
  source = "terraform/modules/kinesis"
  name   = "cdc-stream"
  retention_period = 24
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]
  stream_mode = "ON_DEMAND"
}

# DynamoDB - Kinesis Stream Configuration
resource "aws_dynamodb_kinesis_streaming_destination" "dynamodb-kinesis-stream" {
  stream_arn = module.cdc_kinesis_stream.arn
  table_name = module.orders_dynamodb_table.name
}

# Firehose Role
module "firehose_role" {
  source             = "terraform/modules/iam"
  role_name          = "firehose_role"
  role_description   = "firehose_role"
  policy_name        = "firehose_iam_policy"
  policy_description = "firehose_iam_policy"
  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "firehose.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
    EOF
  policy             = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],
            "Resource": [
                "${module.s3_bucket.arn}",
                "${module.s3_bucket.arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "firehose:PutRecord",
                "firehose:PutRecordBatch"
            ],
            "Resource": [
                "${aws_kinesis_firehose_delivery_stream.cdc_s3_stream.arn}"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords",
                "kinesis:ListShards"
            ],
            "Resource": "${module.cdc_kinesis_stream.arn}"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "lambda:GetFunctionConfiguration"
            ],
            "Resource": "${module.cdc_transform_function.arn}:$LATEST"
        }
      ]
    }
    EOF
}

# Firehose Role
data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "firehose_role" {
  name               = "cdc-firehose-role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

# Kinesis Data Firehose Configuration
resource "aws_kinesis_firehose_delivery_stream" "cdc_s3_stream" {
  name        = "cdc-s3-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.cdc-stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.s3-dest.arn

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
