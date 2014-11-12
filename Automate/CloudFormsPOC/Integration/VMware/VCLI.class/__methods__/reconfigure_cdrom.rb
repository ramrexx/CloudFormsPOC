###################################
#
# EVM Automate Method: Reconfigure_CDROM
#
# This method is used mount/unmount CD/DVD ISOs on a VM
#
# perl cloudforms-mountiso.pl --url https://192.168.252.24:443/sdk/webservice --username Administrator --password mypassword --operation mount --vmname DHCP --datastore NFS-ISO --filename e1000.iso
# perl cloudforms-mountiso.pl --url https://192.168.252.24:443/sdk/webservice --username Administrator --password mypassword --operation umount --vmname DHCP
###################################
begin
  @method = 'Reconfigure_CDROM'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of debugging
  @debug = true


  ###################################
  #
  # Method: reconfigure_cdrom
  #
  ###################################
  def reconfigure_cdrom( vm, operation, datastore, filename )
    # Build the Perl command using the VMDB information
    cmd = "perl /usr/lib/vmware-vcli/apps/vm/CloudForms_Reconfigure_CDROM.pl"
    cmd += " --url https://#{vm.ext_management_system.ipaddress}:443/sdk/webservice"
    cmd += " --username \"#{vm.ext_management_system.authentication_userid}\""
    cmd += " --password \"#{vm.ext_management_system.authentication_password}\""
    cmd += " --vmname \"#{vm.name}\""
    cmd += " --operation \"#{operation}\""
    if operation == 'mount'
      cmd += " --datastore \"#{datastore}\""
      cmd += " --filename \"#{filename}\""
    end
    $evm.log("info", "Running: #{cmd}")
    results = system(cmd)
    return results
  end

  ###################################
  #
  # Method: boolean
  #
  ###################################
  def boolean(string)
    return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
    return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)
  end

  # Dump all root attributes to the automation.log
  #$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - Root:<$evm.root> Attributes - #{k}: #{v}")} if @debug


  # Get vm from root object
  vm = $evm.root['vm']
  raise "#{@method} - VM object not found" if vm.nil?

  # Get root attributes passed in from the service dialog
  operation = $evm.root['operation'] || 'umount'
  datastore = $evm.root['datastore'] || nil
  filename  = $evm.root['filename']  || nil

  $evm.log("info", "#{@method} - Detected Operation:<#{operation}> for VM:<#{vm.name}> Datastore:<#{datastore}> Filename:<#{filename}>")

  results = reconfigure_cdrom( vm, operation, datastore, filename )
  if results
    $evm.log("info", "#{@method} - VM Reconfigure of CD/DVD Successful:<#{results.inspect}>")
    if operation == 'mount'
      vm.custom_set(:DVDROM, filename)
    else
      vm.custom_set(:DVDROM, nil)
    end
  else
    raise "#{@method} - VM Reconfigure of CD/DVD Failed:<#{results.inspect}>"
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
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
