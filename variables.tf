variable "aws_region" {
    description = "Value for aws region"  
    type = string
}
variable "ami" {
  description = "Value for ami"
  type = string
}
variable "instance_type" {
    description = "Value for instance type"
    type = string
}
variable "az_one" {
    description = "Value for AZ1"
    type = string
}
variable "az_two" {
    description = "Value for AZ2"
    type = string
}

variable "account_id" {
    description = "value for aws account ID"
    type = string
}
