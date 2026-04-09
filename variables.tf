variable "aws_region" {}

variable "project_name" {}

variable "vpc_cidr" {}

variable "az_a" {}
variable "az_b" {}

variable "public_subnet_a_cidr" {}
variable "public_subnet_b_cidr" {}

variable "private_app_subnet_a_cidr" {}
variable "private_app_subnet_b_cidr" {}

variable "private_db_subnet_a_cidr" {}
variable "private_db_subnet_b_cidr" {}

variable "app_port" {}

variable "instance_type" {}
variable "ami_id" {}
variable "user_data_path" {}

variable "db_name" {}

variable "db_username" {}

variable "db_password" {
  sensitive = true
}

variable "db_instance_class" {}

variable "multi_az" {}