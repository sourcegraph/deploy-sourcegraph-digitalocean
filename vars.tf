variable "app_name" {
  default     = "sourcegraph"
  description = "Sets the droplet name"
}

variable "region" {
  default     = "sfO2"
  description = "Region, default is sfO2"
}

variable "size" {
  default     = "s-1vcpu-2gb"
  description = "Sets the droplet size"
}

variable "ssh_key_name" {
  default     = "sourcegraph"
  description = "Name of the SSH key"
}

variable "ssh_key_file" {
  default     = ""
  description = "Path to the public key file"
}

