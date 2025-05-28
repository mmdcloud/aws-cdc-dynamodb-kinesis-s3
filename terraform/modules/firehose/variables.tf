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

variable "extended_s3_configuration" {
  description = "Configuration for extended S3 destination"
  type = object({
    role_arn           = string
    bucket_arn         = string
    buffering_interval = number
    buffering_size     = number
    compression_format = string
    processing_configuration = object({
      enabled = bool
      processors = list(object({
        type = string
        parameters = list(object({
          parameter_name  = string
          parameter_value = string
        }))
      }))
    })
  })
  default = null
}