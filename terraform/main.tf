# S3 bucket for storing processed data
module "s3_bucket" {
  source        = "./modules/s3"
  bucket_name   = "madmaxkinesis-s3-dest"
  force_destroy = true
}

module "cdc_function_role" {
  source             = "./modules/iam"
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
  source         = "./modules/dynamodb"
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
  source        = "./modules/lambda"
  filename      = "./files/lambda.zip"
  function_name = "cdc-transform-function"
  role          = module.cdc_function_role.role_arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.12"
  timeout       = 180
}

# Kinesis Data Stream configuration
module "cdc_kinesis_stream" {
  source           = "./modules/kinesis"
  name             = "cdc-stream"
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
  source             = "./modules/iam"
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
              "kinesis:DescribeStream",
              "kinesis:GetShardIterator",
              "kinesis:GetRecords",
              "kinesis:ListShards",
              "kinesis:DescribeStreamSummary"
          ],
          "Resource": "${module.cdc_kinesis_stream.arn}"
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
              "lambda:InvokeFunction",
              "lambda:GetFunctionConfiguration"
          ],
          "Resource": "${module.cdc_transform_function.arn}:*"
        }
      ]
    }
    EOF
}

# Kinesis Data Firehose Configuration
module "cdc_firehose" {
  source             = "./modules/firehose"
  name               = "cdc-s3-stream"
  destination        = "extended_s3"
  kinesis_stream_arn = module.cdc_kinesis_stream.arn
  kinesis_role_arn   = module.firehose_role.role_arn

  extended_s3_configuration = {
    role_arn           = module.firehose_role.role_arn
    bucket_arn         = module.s3_bucket.arn
    buffering_interval = 300
    buffering_size     = 5
    compression_format = "UNCOMPRESSED"
    processing_configuration = {
      enabled = true
      processors = [
        {
          type = "Lambda"
          parameters = [
            {
              parameter_name  = "LambdaArn"
              parameter_value = "${module.cdc_transform_function.arn}:$LATEST"
            }
          ]
        }
      ]
    }
  }
}