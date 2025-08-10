output "subnet_id" {
  description = "Created subnet ID"
  value       = azurerm_subnet.this.id
}

output "name" {
  description = "Created subnet name"
  value       = azurerm_subnet.this.name
}