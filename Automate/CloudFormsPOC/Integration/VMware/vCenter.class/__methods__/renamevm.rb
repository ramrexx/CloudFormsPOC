# RenameVM.rb
#
# Description: This method renames a VM in vCenter
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

def call_vCenter(soap_action, body_hash, vm)
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

  begin
    result = client.call(soap_action) do
      message( body_hash ).to_hash
    end
  rescue => soap_error
    $evm.log(:error, "Error calling soap_action: #{soap_action} error: #{soap_error.class} #{soap_error} result: #{result.inspect rescue nil}")
  end
  $evm.log(:info, "result.success?: #{result.success?}")

  # logout
  logout(client)

  $evm.log(:info, "response: #{result.body["#{soap_action}_response".to_sym]}")
  return result.body["#{soap_action}_response".to_sym]
end

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

# Get dialog_size variable from root hash if nil convert to zero
vm_name = $evm.root['dialog_vm_name']

$evm.log(:info,"Detected VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref} new_name: #{vm_name}")
raise "missing $evm.root['dialog_vm_name']" if vm_name.nil?

body_hash = { '_this' => vm.ems_ref, :attributes! => { 'type' => "VirtualMachine"}, "newName" => ["#{vm_name}"] }

# perform Rename_Task
response = call_vCenter(:rename_task, body_hash, vm)
$evm.log(:info, "response: #{response.inspect}")
#response: {:returnval=>"task-174", :@xmlns=>"urn:vim25"}