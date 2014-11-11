# CheckUnregisteredFromProvider.rb
#
# Description: This method checks to see if the VM is unregistered from the provider
#

vm = $evm.root['vm']

unless vm.nil?
  if !vm.ext_management_system.nil?
    # Bump State
    $evm.log('info', "VM: #{vm.name} has been unregistered from Provider")
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log('info', "VM: #{vm.name} is on Provider: #{vm.ext_management_system.name}")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '15.seconds'
  end
end
