variable "location" {
  type        = string
  description = "Azure location"
  default     = "West Europe"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
  default     = "tf-group"
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the virtual network"
  default     = "tf-vnet"
}

variable "environment" {
  type    = string
  default = "Dev"
}

variable "owner" {
  type    = string
  default = "kiszkahub"
}

variable "allowed_ssh_ip" {
  type        = list(string)
  description = "List of IPs allowed for SSH"
  default     = []
}

variable "aks_name" {
  type        = string
  description = "Name of the Azure Kubernetes Service cluster"
  default     = "tf-aks-cluster"
}

variable "acr_name" {
  type        = string
  description = "Name of the Azure Container Registry"
  default     = "tfacr"
}