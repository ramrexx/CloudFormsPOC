# AddDisk_to_VM.rb
#
# Description: This method is used to add a new disk to an existing VM running on VMware
#

# Get vm object
vm = $evm.root['vm']

# Get the vimVm object
vim_vm = vm.object_send('instance_eval', 'with_provider_object { | vimVm | return vimVm }')

# Get the size for the new disk from the root object
size = $evm.root['dialog_size'].to_i

# Add disk to a VM
unless size.zero?
  $evm.log(:info, "Creating a new #{size}GB disk on Storage: #{vm.storage_name}")
  vim_vm.addDisk("[#{vm.storage_name}]", size * 1024)
end
