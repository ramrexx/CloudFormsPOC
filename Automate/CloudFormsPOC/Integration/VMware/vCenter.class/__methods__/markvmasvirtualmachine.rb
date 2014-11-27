# MarkVMAsVirtualMachine.rb
#
# Description: This method marks a VMware template as a VM
#

require 'savon'

def login(client, username, password)
  result = client.call(:login) do
    message( :_this => "SessionManager", :userName => username, :password => password )
  end
  client.globals.headers( { "Cookie" => result.http.headers["Set-Cookie"] } )
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

# get resource_pool.ems_ref from root
  resource_pool = $evm.root['dialog_resource_pool_ems_ref']

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

mark_as_virtual_machine_result = client.call(:mark_as_virtual_machine) do
  message( { '_this' => vm.ems_ref, :attributes! => { 'type' => "VirtualMachine"},
             'pool' => resource_pool } ).to_hash
end
#$evm.log(:warn, "mark_as_virtual_machine_result: #{mark_as_virtual_machine_result.inspect}")
$evm.log(:info, "mark_as_virtual_machine_result success?: #{mark_as_virtual_machine_result.success?}")

logout(client)
