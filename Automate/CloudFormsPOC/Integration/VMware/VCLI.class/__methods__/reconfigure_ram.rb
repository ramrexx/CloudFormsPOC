###################################
#
# EVM Automate Method: Reconfigure_RAM
#
# This method is used modify a VMs vRAM count
#
# Inputs: $evm.root['vm'], vram, $evm.object['hotadd_vram']
#
###################################
begin
  @method = 'Reconfigure_RAM'

  # Turn of debugging
  @debug = true


  ###################################
  #
  # Method: reconfigure_vram
  #
  ###################################
    def reconfigure_vram(vm, vram )
    # Build the Perl command using the VMDB information
    cmd = "perl /usr/lib/vmware-vcli/apps/vm/CloudForms_Reconfigure_RAM.pl"
    cmd += " --url https://#{vm.ext_management_system.ipaddress}:443/sdk/webservice"
    cmd += " --username \"#{vm.ext_management_system.authentication_userid}\""
    cmd += " --password \"#{vm.ext_management_system.authentication_password}\""
    cmd += " --vmname \"#{vm.name}\""
    cmd += " --vram \"#{vram}\""
    $evm.log("info", "#{@method} - Running: #{cmd}")
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


  # Get vm from root object
  vm = $evm.root['vm']
  raise "#{@method} - VM object not found" if vm.nil?

  # Get root attributes passed in from the service dialog
  vram   = $evm.root['vram'].to_i
  hotadd = $evm.object['hotadd_vram']

  # Get current ram from VM
  vm_vram = vm.mem_cpu.to_i

  unless vram.zero? || vram == vm_vram

    if vram < vm_vram

      if vm.power_state == 'off'
        $evm.log("info", "#{@method} - Reconfiguring VM:<#{vm.name}> vRAM from #{vm_vram} to #{vram} with power state:<#{vm.power_state}>")

        results = reconfigure_vram(vm, vram)
        if results
          $evm.log("info", "#{@method} - VM Reconfigure of vram Successful:<#{results.inspect}>")
        else
          raise "#{@method} - VM Reconfigure of vRAM failed:<#{results.inspect}>"
        end
      else
        $evm.log("info", "#{@method} - Cannot reduce VM:<#{vm.name}> vRAM from <#{vm_vram}> to <#{vram}> with power state #{vm.power_state}")
      end
    else
      # vram count is greater than vm_vram
      if vm.power_state == 'off' || boolean(hotadd)
        $evm.log("info", "#{@method} - Reconfiguring VM:<#{vm.name}> vRAM from <#{vm_vram}> to <#{vram}> with power state:<#{vm.power_state}> and hotadd:<#{hotadd}>")

        results = reconfigure_vram( vm, vram )
        if results
          $evm.log("info", "#{@method} - VM Reconfigure of vRAM Successful:<#{results.inspect}>")
        else
          raise "#{@method} - VM Reconfigure of vRAM failed:<#{results.inspect}>"
        end
      else
        $evm.log("info", "#{@method} - Cannot increase VM:<#{vm.name}> vRAM from #{vm_vram} to #{vram} with power state:<#{vm.power_state}> and hotadd:<#{hotadd}>")
      end
    end
  else
    $evm.log("info", "#{@method} - Skipping vRAM Reconfigure for VM:<#{vm.name}> Currnet vRAM:<#{vm_vram}> Requested vRAM:<#{vram}> with power state:<#{vm.power_state}> and hotadd:<#{hotadd}>")
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
