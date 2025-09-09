variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "retail-eks-public"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"] # two AZs
}

variable "node_group_min" { type = number default = 1 }
variable "node_group_max" { type = number default = 2 }
variable "node_instance_type" { type = string default = "t3.medium" }
