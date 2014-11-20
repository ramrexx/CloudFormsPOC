# ReconfigVM_cpuHotAddEnabled.rb
#
# Description: This method changes a VM's cpuHotAddEnabled switch to true or false in vCenter
#
def call_vcenter(vm, hotadd)
  vm_base = vm.object_send('instance_eval', 'self')
  provider = vm.ext_management_system

  provider.object_send('instance_eval', '
    def reconfigure_vm(vm, hotadd)
      vm.with_provider_object do | vimVm |
        vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
          vmcs.cpuHotAddEnabled = hotadd
        end
        vimVm.send(:reconfig, vmConfigSpec)
      end
    end')
  begin
    $evm.log(:info, "Reconfiguring vm: #{vm.name} cpuHotAddEnabled to #{hotadd}")
    provider.object_send('reconfigure_vm', vm_base, hotadd)
  rescue => myerr
    $evm.log(:error, "Error occurred communicating with vSphere API: #{myerr.class} #{myerr} #{myerr.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
end

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

# Get dialog_size variable from root hash if nil convert to zero
hotadd = $evm.root['dialog_hotadd'] || true

$evm.log(:info,"VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref} hotadd: #{hotadd}")
call_vcenter(vm, hotadd)
