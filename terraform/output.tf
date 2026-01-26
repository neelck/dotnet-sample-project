output "public_ip_address" {
  description = "The actual public IP of the restaurant web server"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.vm.name
}