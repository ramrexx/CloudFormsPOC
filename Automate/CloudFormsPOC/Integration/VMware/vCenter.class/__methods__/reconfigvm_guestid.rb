# ReconfigVM_GuestId.rb
#
# Description: This method changes a VM's guestID in vCenter
#
# Reference: http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.wssdk.apiref.doc/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
#
def call_vcenter(vm, new_guestid)
  vm_base = vm.object_send('instance_eval', 'self')
  provider = vm.ext_management_system

  provider.object_send('instance_eval', '
    def reconfigure_vm(vm, new_guestid)
      vm.with_provider_object do | vimVm |
        vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
          vmcs.guestId = new_guestid
        end
        vimVm.send(:reconfig, vmConfigSpec)
      end
    end')
  begin
    $evm.log(:info, "Changing vm: #{vm.name} guestID: #{vm.hardware.guest_os} to #{new_guestid}")
    provider.object_send('reconfigure_vm', vm_base, new_guestid)
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

# Sample guestId's
# windows7_64Guest, windows8_64Guest, windows8Server64Guest, rhel6_64Guest, rhel7_64Guest, sles12_64Guest, debian7_64Guest
# fedora64Guest, otherLinux64Guest, solaris11_64Guest, otherGuest64, otherGuest, centos64Guest, redhatGuest

# Get dialog_size variable from root hash if nil convert to zero
new_guestid = $evm.root['dialog_new_guestid']
raise "missing $evm.root['dialog_new_guestid']" if new_guestid.nil?

$evm.log(:info,"VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref} new_guestid: #{new_guestid}")
call_vcenter(vm, new_guestid)
