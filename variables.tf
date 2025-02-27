# ${var.app_name}
variable "app_name" {
    default = "carpathia"
    type    = string
}

# ${var.env}
variable "env" {
    type = string
}

# ${var.instance_size}
variable "instance_size" {
    default = "t3.small"
    type    = string
}

# ${var.asg_max_size}
variable "asg_max_size" {
    default = 1
    type    = number
}

# ${var.asg_min_size}
variable "asg_min_size" {
    default = 0
    type    = number
}

# ${var.asg_desired_capacity}
variable "asg_desired_capacity" {
    default = 0
    type    = number
}

variable "s3fs_directories" {
  default = [
    "var/log/podaac/",
    "bootstrap/",
    "home/ssm-user/"
  ]
}

variable "ssm_parameter" {
    type    = string
}