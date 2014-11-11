# PreDeleteFromProvider.rb
#
# Description: This retirement method runs prior to deleting the VM from the Provider
#

vm = $evm.root['vm']

unless vm.nil?
  power_state = vm.attributes['power_state']
  ems = vm.ext_management_system
  $evm.log(:info, "VM: #{vm.name} on Provider: #{ems ? ems.name : nil} has Power State: #{power_state}")
end
