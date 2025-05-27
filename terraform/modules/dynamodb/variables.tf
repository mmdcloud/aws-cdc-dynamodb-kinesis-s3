variable "name" {
  description = "The name of the DynamoDB table"
  type        = string
}
variable "billing_mode" {
  description = "The name of the DynamoDB table"
  type        = string
}
variable "read_capacity" {
  description = "The name of the DynamoDB table"
  type        = number
}
variable "write_capacity" {
  description = "The name of the DynamoDB table"
  type        = number
}
variable "hash_key" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "attributes" {
  type = list(object({
    name = string
    type = string
  }))
  description = "List of attributes for the DynamoDB table"
  default     = []
}

variable "ttl_attribute_name" {
  description = "The name of the TTL attribute"
  type        = string
  default     = "TimeToExist"
  
}

variable "ttl_enabled" {
  description = "Whether TTL is enabled for the DynamoDB table"
  type        = bool
  default     = true
}