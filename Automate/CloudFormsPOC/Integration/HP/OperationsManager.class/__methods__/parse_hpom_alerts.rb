###################################
#
# EVM Automate Method: Parse_HPOM_Alerts
#
# Notes: This method is used to parse incoming HPOM Alerts
#
###################################
begin
  @method = 'Parse_HPOM_Alerts'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Dump in-storage objects to the log
  def dumpObjects()
    return unless @debug
    # List all of the objects in the root object
    $evm.log("info", "#{@method} ===========================================") if @debug
    $evm.log("info", "#{@method} In-storage ROOT Objects:") if @debug
    $evm.root.attributes.sort.each { |k, v|
      $evm.log("info", "#{@method} -- \t#{k}: #{v}") if @debug

      #$evm.log("info", "#{@method} Inspecting #{v}: #{v.inspect}") if @debug
    }
    $evm.log("info", "#{@method} ===========================================") if @debug

  end

  # List the types of object we will try to detect
  obj_types = %w{ vm host storage ems_cluster ext_management_system }
  obj_type = $evm.root.attributes.detect { |k,v| obj_types.include?(k)}



  # If obj_type is NOT nil else assume miq_server
  unless obj_type.nil?
    rootobj = obj_type.first
  else
    rootobj = 'miq_server'
  end

  $evm.log("info", "#{@method} - Root Object:<#{rootobj}> Detected") if @debug

  $evm.root['object_type'] = rootobj

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
