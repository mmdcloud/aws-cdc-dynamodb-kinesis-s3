variable "name" {
    description = "The name of the Firehose delivery stream"
    type        = string
}

variable "destination" {
    description = "The destination of the Firehose delivery stream"
    type        = string
}

variable "kinesis_stream_arn" {
    description = "The ARN of the Kinesis stream to deliver data to"
    type        = string  
}

variable "kinesis_role_arn" {
    description = "The ARN of the IAM role that Firehose uses to access the Kinesis stream"
    type        = string  
}

variable "s3_role_arn" {
    description = "The ARN of the IAM role that Firehose uses to access the S3 bucket"
    type        = string  
}

variable "s3_bucket_arn" {
    description = "The ARN of the S3 bucket where Firehose delivers data"
    type        = string    
}