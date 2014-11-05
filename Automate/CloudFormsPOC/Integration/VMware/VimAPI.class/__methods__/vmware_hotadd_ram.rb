###################################
#
# EVM Automate Method: VMware_HotAdd_RAM
#
# This method is used to modify vRAM to an existing VM running on VMware
#
# Inputs: $evm.root['vm'], dialog_ram
#
###################################
# Method for logging
def log(level, message)
  @method = 'VMware_HotAdd_RAM'
  @debug = true
  $evm.log(level, "#{@method}: #{message}") if @debug
end

begin
  log(:info, 'EVM Automate Method Started')

  # Get vm object from root
  vm = $evm.root['vm']
  raise MissingVMObject, "Missing $evm.root['vm'] object" unless vm

  # Get the number of cpus from root
  ram = $evm.root['dialog_ram'].to_i
  log(:info, "Detected ram:<#{ram}>")

  unless ram.zero?
    log(:info, "Setting amount of vRAM to #{ram} on VM:<#{vm.name}>")
    vm.object_send('instance_eval', "with_provider_object { | vimVm | vimVm.setMemory(#{ram}) }")
  end

  #
  # Exit method
  #
  log(:info, 'EVM Automate Method Ended')
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
