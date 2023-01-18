variable "aws_region" {
  description = "AWS region name."
  type        = string
  nullable    = false
  default     = "ap-southeast-1"
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
  nullable    = false
  default     = "RG-serverless_lambda_apigw"
}

variable "resource_tags" {
  description = "Resource tag identification."
  nullable    = false
  default = {
    use_case = "serverless_lambda_apigw"
  }
}
