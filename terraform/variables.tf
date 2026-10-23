variable "subscription_id" {
  type = string
}

variable "location" {
  type = string
}

variable "name_suffix" {
  type = string
}

variable "acr_name" {
  type = string
}

variable "image_name" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "apply_principal_id" {
  type = string
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
}
