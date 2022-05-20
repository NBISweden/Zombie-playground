variable "ssh_key_path" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "master_flavor_name" {
  description = "instance flavor name"
  type        = string
}
variable "master-1_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "master-2_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "master-3_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "worker-1_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "worker-2_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "worker-3_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "worker-4_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "worker-5_flavor_name" {
  description = "instance flavor name"
  type        = string
  default     = ""
}
variable "worker_flavor_name" {
  description = "instance flavor name"
  type        = string
}

variable "image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
}
variable "master-1_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "master-2_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "master-3_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "worker-1_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "worker-2_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "worker-3_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "worker-4_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "worker-5_image_name" {
  description = "Name of an image to boot the instance from"
  type        = string
  default     = ""
}
variable "secgroups" {
  description = "secgroups"
}

variable "cloud_init_data" {
  description = "cloud init script"
}
variable "bastion_host" {
  description = "IP to the bastion host"
  type        = string
}
variable "bastion_user" {
  description = "user when connecting to the bastion host"
  type        = string
}

variable "k8s_version" {
  type = string
}

variable "cluster_prefix" {
  type = string
}

variable "cluster_update" {
  type = bool
}

variable "external_hostname" {
  type = string
}
