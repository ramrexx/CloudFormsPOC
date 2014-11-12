###################################
#
# EVM Automate Method: retireVM
#
# This method is called via web services to have a VM enter retirement
#
# Inputs: VM GUID
#
###################################
begin
  @method = 'retireVM'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true


  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")} if @debug

  # Get VM object from the root object
  vm = $evm.root['vm']

  # If VM is nil then look for GUID from root object
  if vm.nil?
    $evm.log("info","Execution of method:<#{@method}> via API detected") if @debug
    # Get GUID from foot object
    guid = $evm.root['guid']

    # Lookup VM by GUID
    vm = $evm.vmdb('vm').find_by_guid(guid)
    # Bail out if VM is not found
    raise "VM with GUID:<#{guid}> not found" if vm.nil?
    $evm.log("info","Assigning VM:<#{vm.name}> to root object") if @debug
    $evm.root['vm'] = vm
    $evm.log("info","Found VM:<#{vm.name}> via GUID:<#{guid}>") if @debug
  end

  $evm.log("info","Retiring VM:<#{vm.name}> at:<#{Time.now}>") if @debug
  vm.retire_now

  #$evm.log("info","Inspecting VM:<#{vm.name}> object:<#{$evm.root['vm'].inspect}>") if @debug

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
