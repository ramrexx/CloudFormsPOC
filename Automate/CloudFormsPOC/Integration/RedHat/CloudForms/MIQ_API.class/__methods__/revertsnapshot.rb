###################################
#
# EVM Automate Method: revertSnapshot
#
# Notes: This method reverts to a snapshot on a given VM via web service API
#
# Inputs: GUID, [snap_name=current|<snapshot_name>]
#
###################################
begin
  @method = 'revertSnapshot'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  # Get VM form root object
  vm = $evm.root['vm']

  # Get Snapshot Name from root object
  snap_name = $evm.root['snap_name'] || 'current'
  $evm.log("info","#{@method} - Snapshot Name:<#{snap_name}>")

  # If VM is nil then assume web service call and look for GUID from root object
  if vm.nil?
    $evm.log("info","#{@method} - Execution via API detected")
    # Get GUID from foot object
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
  $evm.log("info","#{@method} - Reverting Snapshot:<#{snapshot.name}> Description:<#{snapshot.description}> Date:<#{snapshot.updated_on}> for VM:<#{vm.name}>")
      snapshot.revert_to
    end
  else
    # Remove a specific snapshot
    snapshot =  snapshots.detect {|ss| ss.name == snap_name}
  $evm.log("info","#{@method} - Reverting Snapshot:<#{snapshot.name}> Description:<#{snapshot.description}> Date:<#{snapshot.updated_on}> for VM:<#{vm.name}>")
    snapshot.revert_to
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
