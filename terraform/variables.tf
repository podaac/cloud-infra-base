variable "app_name" {
    default = "carpathia"
    type    = string
}

variable "stage" {
    type = string
}

variable "region" {
  type = string
}

variable "resource_prefix" {
    type = string
    default = null
}

variable "default_tags" {
    type = map(string)
    default = {}
}

variable "instance_size" {
    default = "t3.small"
    type    = string
}

variable "ebs_size_gb" {
    default = 100
    type    = number
}

variable "asg_max_size" {
    default = 1
    type    = number
}

variable "asg_min_size" {
    default = 1
    type    = number
}

variable "s3fs_directories" {
  default = [
    "var/log/podaac/",
    "bootstrap/",
    "home/ssm-user/"
  ]
}

variable "ami_ssm_key" {
    type    = string
    default = "/ngap/amis/image_id_al2023_x86"
}

variable "read_only_accounts" {
    description = "List of AWS account IDs that can read the S3 buckets."
    type        = list(string)
    default     = []
}

variable "rotation_period" {
  default = 1
  description = "Value in days to rotate the EC2 AMI. Set to 0 to disable rotation."
  type    = number
}

variable "notification_emails" {
  type    = list(string)
  default = []
  description = "Email addresses to notify when AMI rotation occurs."
}
