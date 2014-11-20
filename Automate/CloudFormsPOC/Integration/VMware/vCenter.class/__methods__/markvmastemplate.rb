# MarkVMAsTemplate.rb
#
# Description: This method marks a VM as a template in vCenter
#

def call_vcenter(vm)
  vm_base = vm.object_send('instance_eval', 'self')
  provider = vm.ext_management_system

  provider.object_send('instance_eval', '
    def mark_as_template(vm)
      vm.with_provider_object do | vimVm |
        vimVm.send(:markAsTemplate)
      end
    end')
  begin
    $evm.log(:info, "Marking vm: #{vm.name} as a template")
    provider.object_send('mark_as_template', vm_base)
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

$evm.log(:info,"VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref}")
call_vcenter(vm)
