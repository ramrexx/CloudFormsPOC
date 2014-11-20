# DumpVM_Info.rb
#
# Description: This method renames a VM in vCenter
#

def call_vcenter(vm)
  vm_base = vm.object_send('instance_eval', 'self')
  provider = vm.ext_management_system
  provider.object_send('instance_eval', '
    def query_vimVM(myevm, vm)
      property_values = {}
      vm.with_provider_object do | vimVm |
        config = vimVm.send(:getProp, "config")["config"]
        property_values["guestId"] = config["guestId"]
      end
        myevm.log(:info, "property_values: #{property_values.inspect}")
    end')
  begin
    property_values = provider.object_send('query_vimVM', $evm, vm_base) 
  rescue => myerr
    $evm.log(:error, "Error occurred communicating with vSphere API: #{myerr.class} #{myerr} #{myerr.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
  return property_values
end

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

$evm.log(:info,"VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref}")
property_values = call_vcenter(vm)
$evm.log(:info, "property_values: #{property_values.inspect}")
