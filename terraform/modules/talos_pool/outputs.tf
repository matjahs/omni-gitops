output "names" {
  description = "The names of the created VMs."
  value       = [for vm in vsphere_virtual_machine.main : vm.name]
}

output "virtual_machines" {
  description = "The created virtual machines."
  value       = [for vm in vsphere_virtual_machine.main : vm]
}
