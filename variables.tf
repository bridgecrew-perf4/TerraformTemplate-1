variable "aws_credentials_filepath" {
  description = "File path to your local aws credentials file"
  default = "HOME/.aws/credentials"
}


variable "aws_region" {
  description = "AWS Region for London"
  type        = string
  default     = "eu-west-2"
}


variable "ec2-instance-type" {
  description = "EC2 Instance type"
  type        = string
  default     = "t2.micro"
}


variable "all-non-local-addresses" {
  description = "Address for all non-local"
  type = string
  default = "0.0.0.0/0"
}


variable "subnet_info" {
  description = "cidr block for the subnet + the name tag"
}
