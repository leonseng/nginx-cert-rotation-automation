variable "aws_region" {
  type = string
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aws_az_count" {
  type    = number
  default = 1
}

variable "project_name" {
  type    = string
  default = "nginx-dynamic-tls-aws-"
}

variable "ssh_public_key" {
  description = "SSH public key to be loaded onto all EC2 instances for SSH access"
  type        = string
}

variable "secrets_manager_target_tag" {
  description = "Tag name for discovering secrets containing NGINX cert key pair"
  type        = string
  default     = "nginx-dynamic-tls-aws"
}

variable "nginx_ec2_target_tag" {
  description = "Tag name for Lambda to discover NGINX instances"
  type        = string
  default     = "nginx-dynamic-tls-aws"
}
