output "ansible_inventory" {
  description = "Ansible inventory in JSON format."
  value       = jsonencode(local.ansible_inventory)
}

output "ansible_inventory_object" {
  description = "Ansible inventory as a Terraform object (not JSON-encoded)."
  value       = local.ansible_inventory
}
