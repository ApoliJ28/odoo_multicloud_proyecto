variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Rango CIDR para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "access_key" {
    description = "AWS access key"
    type        = string
}

variable "secret_key" {
    description = "AWS secret key"
    type        = string
}

variable "session_token" {
    description = "AWS session token"
    type        = string
}