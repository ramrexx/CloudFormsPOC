# ReconfigVM_Task_guestID.rb
#
# Description: This method changes a VMware VM's guestID to RHEL7 x86_64
#
# Reference: http://pubs.vmware.com/vsphere-55/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc%2Fvim.vm.GuestOsDescriptor.GuestOsIdentifier.html
#
require 'savon'

def login(client, username, password)
  result = client.call(:login) do
    message( :_this => "SessionManager", :userName => username, :password => password )
  end
  client.globals.headers({ "Cookie" => result.http.headers["Set-Cookie"] })
end

def logout(client)
  begin
    client.call(:logout) do
      message(:_this => "SessionManager")
    end
  rescue => logouterr
    $evm.log(:error, "Error logging out #{logouterr.class} #{logouterr}")
  end
end

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

$evm.log(:info,"Detected VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref}")

# get servername and credentials from vm.ext_management_system
servername = vm.ext_management_system.ipaddress
username = vm.ext_management_system.authentication_userid
password = vm.ext_management_system.authentication_password

client = Savon.client(
  :wsdl => "https://#{servername}/sdk/vim.wsdl",
  :endpoint => "https://#{servername}/sdk/",
  :ssl_verify_mode => :none,
  :ssl_version => :TLSv1,
  :raise_errors => false,
  :log_level => :info,
  :log => false
)
#client.operations.sort.each { |operation| $evm.log(:info, "Savon Operation: #{operation}") }

# login and set cookie
login(client, username, password)

reconfig_vm_task_result = client.call(:reconfig_vm_task) do
  message( '_this' => vm.ems_ref, :attributes! => { 'type' => 'VirtualMachine' },
    'spec' => {'guestId' => ['rhel7_64Guest']}, :attributes! => { 'type' => 'VirtualMachineConfigSpec' }  ).to_hash
end
# {"type"=>"VirtualMachineConfigSpec", 
# "name"=>["vm"], 
# "guestId"=>["otherGuest64"],
$evm.log(:warn, "reconfig_vm_task_result: #{reconfig_vm_task_result.inspect}")
$evm.log(:info, "reconfig_vm_task_result success?: #{reconfig_vm_task_result.success?}")

logout(client)
