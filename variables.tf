variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "cognito_region" {
  description = "Region for Cognito (used in JWT issuer URLs)"
  type        = string
  default     = "eu-north-1"
}

variable "bucket_suffix_byte_length" {
  description = "Byte length for random_id used in bucket names"
  type        = number
  default     = 4
}