# check_powered_off.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method checks to see if the VM has been powered off
#
vm = $evm.root['vm']
raise "VM not found" if vm.nil?
$evm.log(:info, "VM: #{vm.name} vendor: #{vm.vendor} with power_state: #{vm.power_state} tags: #{vm.tags}")

# If VM is powered off or suspended exit
if vm.power_state == 'off'
  $evm.root['ae_result'] = 'ok'
elsif vm.power_state == 'never' || vm.power_state == 'suspended'
  $evm.root['ae_result'] = 'error'
else
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '15.seconds'
end
