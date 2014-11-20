# ReconfigVM_Rename.rb
#
# Description: This method renames a VM in vCenter
#

def call_vcenter(vm, new_vm_name)
  vm_base = vm.object_send('instance_eval', 'self')
  provider = vm.ext_management_system

  provider.object_send('instance_eval', '
    def reconfigure_vm(vm, new_vm_name)
      vm.with_provider_object do | vimVm |
        vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
          vmcs.name = new_vm_name
        end
        vimVm.send(:reconfig, vmConfigSpec)
      end
    end')
  begin
    $evm.log(:info, "Renaming vm: #{vm.name} to #{new_vm_name}")
    provider.object_send('reconfigure_vm', vm_base, new_vm_name)
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
new_vm_name = $evm.root['dialog_new_vm_name']
raise "missing $evm.root['dialog_new_vm_name']" if new_vm_name.nil?

$evm.log(:info,"VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref} new_vm_name: #{new_vm_name}")
call_vcenter(vm, new_vm_name)
