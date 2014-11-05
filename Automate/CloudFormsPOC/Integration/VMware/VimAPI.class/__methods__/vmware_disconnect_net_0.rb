###################################
#
# EVM Automate Method: VMWare_Disconnect_Net_0
#
# This method is used to  disconnect the network fro nic 0 vmware only
#
# Red Hat: Bill Helgeson, Jason Dillaman
###################################
begin

# Method for logging
  def log(level, message)
    @method = 'VMWare_Disconnect_Net_0'
    $evm.log(level, "#{@method} - #{message}")
  end
  log(:info, "EVM Automate Method Started")
  prov = $evm.root['miq_provision'] || $evm.root['miq_provision_request'] || $evm.root['miq_provision_request_template']
  vm = prov.vm

  vm_base = vm.object_send('instance_eval', 'self')
  $evm.log("info","VMbase: #{vm_base.inspect}")
  ems = vm.ext_management_system
  ems.object_send('instance_eval', '
  def set_nic_connected(vm, nicIndex, connected)
    self.get_vim_vm_by_mor(vm.ems_ref) do | vimVm |
      #matchedDev = vimVm.send(:getProp, "config.hardware")["config"]["hardware"]["device"].collect do |dev|
      #  dev if dev.xsiType == "VirtualVmxnet3"
      #end.compact.sort_by { |d| d["unitNumber"] }[nicIndex]
      matchedDev = vimVm.send(:getProp, "config.hardware")["config"]["hardware"]["device"].select {|d| d.has_key?("macAddress") }.sort_by { |d| d["unitNumber"] }[nicIndex]
      raise "set_nic_connected: nic #{nicIndex} not found" unless matchedDev

      vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
        vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
          vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
            vdcs.operation = "edit".freeze
            vdcs.device    = VimHash.new("VirtualVmxnet3") do |vDev|
              vDev.key           = matchedDev["key"]
              vDev.controllerKey = matchedDev["controllerKey"]
              vDev.unitNumber    = matchedDev["unitNumber"]
              vDev.backing       = matchedDev["backing"]
              vDev.connectable = VimHash.new("VirtualDeviceConnectInfo") do |con|
                con.startConnected = connected
                con.connected      = connected
                con.allowGuestContol = true
              end
            end
          end
        end
      end

      vimVm.send(:reconfig, vmConfigSpec)
    end
  end')
  ems.object_send('set_nic_connected', vm_base, 0, false)

  ############
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
