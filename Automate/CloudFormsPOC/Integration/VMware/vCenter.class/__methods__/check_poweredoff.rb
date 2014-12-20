# Check_PoweredOff.rb
#
# Description: This method checks to ensure that the VM's guestID has been set
#
def retry_method(retry_time, msg)
  $evm.log('info', "#{msg} - Waiting #{retry_time} seconds}")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor: #{vm.vendor}" unless vm.vendor.downcase == 'vmware'

raise "Templates are not allowed" if vm.template

$evm.log(:info,"Detected VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref} power_state: #{vm.power_state}")
retry_method(15.seconds, "VM: #{vm.name} power_state: #{vm.power_state}") unless vm.power_state == 'off'
