# check_vm_tags.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method checks for rightsize tag and stops the VM
#
category = :rightsize

vm = $evm.root['vm']
raise "VM not found" if vm.nil?
$evm.log(:info, "Found VM: #{vm.name} vendor: #{vm.vendor} tags: #{vm.tags}")

raise "Invalid vendor: #{vm.vendor}" unless vm.vendor.downcase == 'vmware'

rightsizing = vm.tags(category).first rescue nil
raise "VM: #{vm.name} is not tagged with #{category}" if rightsizing.nil?

if vm.power_state == 'on'
  $evm.log(:info, "Stopping VM: #{vm.name}")
  vm.stop
end
