###################################
#
# EVM Automate Method: VMware_HotAdd_Disk
#
# This method is used to add a new disk to an existing VM running on VMware
#
# Inputs: $evm.root['vm'], dialog_size
#
###################################
# Method for logging
def log(level, message)
  @method = 'VMware_HotAdd_Disk'
  @debug = true
  $evm.log(level, "#{@method}: #{message}") if @debug
end

begin
  log(:info, "EVM Automate Method Started")

  # Get vm object
  vm = $evm.root['vm']
  raise MissingVMObject, "Missing $evm.root['vm'] object" unless vm

  # Get the vimVm object
  vim_vm = vm.object_send('instance_eval', 'with_provider_object { | vimVm | return vimVm }')

  # Get the size for the new disk from the root object
  size = $evm.root['dialog_size'].to_i
  log(:info, "Detected size:<#{size}>")

  # Add disk to a VM
  unless size.zero?
    log(:info, "Creating a new #{size}GB disk on Storage:<#{vm.storage_name}>")
    vim_vm.addDisk("[#{vm.storage_name}]", size * 1024)
  else
    log(:error, "Size:<#{size}> invalid")
  end

  #
  # Exit method
  #
  log(:info, "EVM Automate Method Ended")
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
