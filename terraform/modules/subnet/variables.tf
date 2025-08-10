variable "name" {
  type        = string
  description = "Subnet name"
}
variable "resource_group_name" {
  type        = string
  description = "Resource group to which the subnet belongs"
}
variable "virtual_network_name" {
  type        = string
  description = "Virtual network to which the subnet belongs"
}
variable "address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the subnet"
}