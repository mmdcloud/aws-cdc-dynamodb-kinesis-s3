# S3 bucket for storing processed data
resource "aws_s3_bucket" "s3-dest" {
  bucket       = "theplayer007-s3-dest"
  force_destroy = true
  tags = {
    Name = "theplayer007-s3-dest"
  }
}

# Lambda Function Role
resource "aws_iam_role" "cdc-function-role" {
  name               = "cdc-function-role"
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
  tags = {
    Name = "cdc-function-role"
  }
}

# Lambda Function Policy
resource "aws_iam_policy" "cdc-function-policy" {
  name        = "cdc-function-policy"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
       {
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "*",
          "Effect": "Allow"
       } 
      ]
    }
    EOF
  tags = {
    Name = "cdc-function-policy"
  }
}

# Lambda Function Role-Policy Attachment
resource "aws_iam_role_policy_attachment" "cdc-function-policy-attachment" {
  role       = aws_iam_role.cdc-function-role.name
  policy_arn = aws_iam_policy.cdc-function-policy.arn
}

# DynamoDB table
resource "aws_dynamodb_table" "orders-dynamodb-table" {
  name           = "orders"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "roll_no"

  attribute {
    name = "roll_no"
    type = "N"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }
}

# Lambda function configuration
resource "aws_lambda_function" "cdc-transform-function" {
  filename      = "lambda.zip"
  function_name = "cdc-transform-function"
  role          = aws_iam_role.cdc-function-role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  tags = {
    Name = "cdc-transform-function"
  }
}

# Kinesis Data Stream configuration
resource "aws_kinesis_stream" "cdc-stream" {
  name             = "cdc-stream"
  retention_period = 24
  
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Name = "cdc-stream"
  }
}

# DynamoDB - Kinesis Stream Configuration
resource "aws_dynamodb_kinesis_streaming_destination" "dynamodb-kinesis-stream" {
  stream_arn = aws_kinesis_stream.cdc-stream.arn
  table_name = aws_dynamodb_table.orders-dynamodb-table.name
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

resource "aws_iam_policy" "firehose_s3" {
  name_prefix = "firehose-s3"
  policy      = <<-EOF
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
            "${aws_s3_bucket.s3-dest.arn}",
            "${aws_s3_bucket.s3-dest.arn}/*"
        ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_s3" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_s3.arn
}

resource "aws_iam_policy" "firehose_put_record" {
  name_prefix = "firehose_put_record"
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "firehose:PutRecord",
                "firehose:PutRecordBatch"
            ],
            "Resource": [
                "${aws_kinesis_firehose_delivery_stream.cdc_s3_stream.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_put_record" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_put_record.arn
}

resource "aws_iam_policy" "firehose_cloudwatch" {
  name_prefix = "firehose-cloudwatch"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": [
            "${aws_cloudwatch_log_group.firehose_log_group.arn}"
        ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_cloudwatch" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_cloudwatch.arn
}

resource "aws_iam_policy" "kinesis_firehose" {
  name_prefix = "kinesis-firehose"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.cdc-stream.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kinesis_firehose" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.kinesis_firehose.arn
}

resource "aws_iam_role" "firehose_role" {
  name               = "cdc-firehose-role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

# Cloudwatch Log Group and Stream
resource "aws_cloudwatch_log_group" "firehose_log_group" {
  name = "/aws/kinesisfirehose/firehose-log-group"

  tags = {
    Name = "firehose-log-group"
  }
}

resource "aws_cloudwatch_log_stream" "firehose_log_stream" {
  name           = "/aws/kinesisfirehose/firehose-log-stream"
  log_group_name = aws_cloudwatch_log_group.firehose_log_group.name
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
    
    cloudwatch_logging_options {
      enabled = "true"
      log_group_name = aws_cloudwatch_log_group.firehose_log_group.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_stream.name
    }	
 
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
