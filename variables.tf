# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "function_name" {
  default = "dentist_app"
}

variable "path_source_code" {
  default = "lambda_function"
}
