# Kinesis Data Firehose Configuration
resource "aws_kinesis_firehose_delivery_stream" "delivery_stream" {
  name        = var.name
  destination = var.destination

  kinesis_source_configuration {
    kinesis_stream_arn = var.kinesis_stream_arn
    role_arn           = var.kinesis_role_arn
  }

  dynamic "extended_s3_configuration" {
    for_each = var.extended_s3_configuration != null ? [1] : []
    content {
      role_arn           = var.extended_s3_configuration.role_arn
      bucket_arn         = var.extended_s3_configuration.bucket_arn
      buffering_interval = var.extended_s3_configuration.buffering_interval
      buffering_size     = var.extended_s3_configuration.buffering_size
      compression_format = var.extended_s3_configuration.compression_format
      
      dynamic "processing_configuration" {
        for_each = var.extended_s3_configuration.processing_configuration != null ? [1] : []
        content {
          enabled = var.extended_s3_configuration.processing_configuration.enabled
          
          dynamic "processors" {
            for_each = var.extended_s3_configuration.processing_configuration.processors
            content {
              type = processors.value.type
              
              dynamic "parameters" {
                for_each = processors.value.parameters
                content {
                  parameter_name  = parameters.value.parameter_name
                  parameter_value = parameters.value.parameter_value
                }
              }
            }
          }
        }
      }
    }
  }
}