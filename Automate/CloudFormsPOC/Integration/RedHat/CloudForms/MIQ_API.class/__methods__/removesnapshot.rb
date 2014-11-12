###################################
#
# EVM Automate Method: removeSnapshot
#
# Notes: This method will remove snapshot(s) on a given VM via web service API
#
# Inputs: GUID, [snap_name=current|all|<snapshot-name>]
#
###################################
begin
  @method = 'removeSnapshot'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true


  # Assume script executing from button
  vm = $evm.root['vm']


  # Get Snapshot Name from root object else use the current snapshot to remove
  snap_name = $evm.root['snap_name'] || 'current'
  $evm.log("info","#{@method} - Snapshot Name:<#{snap_name}>")


  # If VM is nil then look for GUID from root object
  if vm.nil?
    $evm.log("info","#{@method} - Execution of method:<#{@method}> via API detected")
    # Get GUID from root object
    guid = $evm.root['guid']

    # Lookup VM by GUID
    vm = $evm.vmdb('vm').find_by_guid(guid)
    # Bail out if VM is not found
    raise "#{@method} - VM with GUID:<#{guid}> not found" if vm.nil?
    $evm.log("info","#{@method} - Found VM:<#{vm.name}> via GUID:<#{guid}>")
  end
  $evm.log("info","#{@method} - VM GUID:<#{guid}>")

  # Get all snapshots on current VM
  snapshots = vm.snapshots
  if snapshots.nil?
    $evm.log("info","#{@method} - VM:<#{vm.name}> has no snapshots")
    exit_MIQ_OK
  end

  case snap_name
  when 'current'
    # Find the current snapshot and remove it
    snapshot = snapshots.detect {|ss| ss.current?}
    unless snapshot.nil?
      $evm.log("info","#{@method} - VM:<#{vm.name}> Removing snapshot:<#{snapshot.name}>")
      snapshot.remove
    end
  when 'all'
    # Remove all snapshots from the VM
    $evm.log("info","#{@method} - VM:<#{vm.name}> removing all snapshots:<#{snapshots.inspect}>")
    vm.remove_all_snapshots
  else
    # Remove a specific snapshot
    snapshot =  snapshots.detect {|ss| ss.name == snap_name}
    $evm.log("info","#{@method} - VM:<#{vm.name}> removing snapshot:<#{snapshot.name}>")
    snapshot.remove
  end


  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK


  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
