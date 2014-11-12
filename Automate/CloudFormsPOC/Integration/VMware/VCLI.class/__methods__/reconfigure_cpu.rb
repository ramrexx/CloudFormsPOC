###################################
#
# EVM Automate Method: Reconfigure_CPU
#
# This method is used modify a VMs vCPU count
#
# Inputs: $evm.root['vm'], vcpu, $evm.object['hotadd_vcpu']
#
###################################
begin
  @method = 'Reconfigure_CPU'

  # Turn of debugging
  @debug = true


  ###################################
  #
  # Method: reconfigure_cpu
  #
  ###################################
    def reconfigure_vcpu(vm, vcpu )
    # Build the Perl command using the VMDB information
    cmd = "perl /usr/lib/vmware-vcli/apps/vm/CloudForms_Reconfigure_CPU.pl"
    cmd += " --url https://#{vm.ext_management_system.ipaddress}:443/sdk/webservice"
    cmd += " --username \"#{vm.ext_management_system.authentication_userid}\""
    cmd += " --password \"#{vm.ext_management_system.authentication_password}\""
    cmd += " --vmname \"#{vm.name}\""
    cmd += " --vcpu \"#{vcpu}\""
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
  vcpu   = $evm.root['vcpu'].to_i

  # Get hotadd_vcpu attribute from model
  hotadd = $evm.object['hotadd_vcpu']

  # Get current vcpu from VM
  vm_vcpu = vm.num_cpu.to_i

  unless vcpu.zero? || vcpu == vm_vcpu

    if vcpu < vm_vcpu

      if vm.power_state == 'off'
        $evm.log("info", "#{@method} - Reconfiguring VM:<#{vm.name}> vCPU from #{vm_vcpu} to #{vcpu} with power state:<#{vm.power_state}>")

        results = reconfigure_vcpu(vm, vcpu)
        if results
          $evm.log("info", "#{@method} - VM Reconfigure of vCPU Successful:<#{results.inspect}>")
        else
          raise "#{@method} - VM Reconfigure of vCPU failed:<#{results.inspect}>"
        end
      else
        $evm.log("info", "#{@method} - Cannot reduce VM:<#{vm.name}> vCPU from #{vm_vcpu} to #{vcpu} with power state:<#{vm.power_state}>")
      end
    else
      # vcpu count is greater than vm_vcpu
      if vm.power_state == 'off' || boolean(hotadd)
        $evm.log("info", "#{@method} - Reconfiguring VM:<#{vm.name}> vCPU from #{vm_vcpu} to #{vcpu} with power state:<#{vm.power_state}> and hotadd:<#{hotadd}>")

        results = reconfigure_vcpu( vm, vcpu )
        if results
          $evm.log("info", "#{@method} - VM Reconfigure of vCPU Successful:<#{results.inspect}>")
        else
          raise "#{@method} - VM Reconfigure of vCPU failed:<#{results.inspect}>"
        end
      else
        $evm.log("info", "#{@method} - Cannot increase VM:<#{vm.name}> vCPU count from #{vm_vcpu} to #{vcpu} with power state:<#{vm.power_state}> and hotadd:<#{hotadd}>")
      end
    end
  else
    $evm.log("info", "#{@method} - Skipping vCPU Reconfigure for VM:<#{vm.name}> Currnet vCPU count:<#{vm_vcpu}> Requested vCPU Count:<#{vcpu}> with power state:<#{vm.power_state}> and hotadd:<#{hotadd}>")
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
