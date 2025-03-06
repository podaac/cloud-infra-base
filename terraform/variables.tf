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
