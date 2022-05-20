variable "ssh_key_path" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "flavor_name" {
  description = "instance flavor name"
  type        = string
}

variable "image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
}

variable "secgroups" {
  description = "secgroups"
}

variable "cloud_init_data" {
  description = "cloud init script"
}