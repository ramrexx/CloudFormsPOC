# vMotion.rb
#
# Description: This method vMotions a VM in vCenter
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

$evm.root.attributes.sort.each { |k, v| $evm.log(:info,"Root:<$evm.root> Attributes - #{k}: #{v}")}

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

$evm.log(:info,"Detected VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref}")

# get resource_pool.ems_ref from root
resource_pool_ems_ref = $evm.root['dialog_resource_pool_ems_ref']
datastore_ems_ref = $evm.root['dialog_datastore_ems_ref']

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

body_hash={}
body_hash['_this'] = vm.ems_ref
body_hash[:attributes!] = { 'type' => 'VirtualMachine' }
body_hash['spec'] = {}
body_hash['spec']['datastore'] = datastore_ems_ref unless datastore_ems_ref.nil? && vm.storage.ems_ref == datastore_ems_ref
body_hash['spec']['pool'] = resource_pool_ems_ref unless resource_pool_ems_ref.nil? && vm.resource_pool.ems_ref == resource_pool_ems_ref
body_hash['spec'][:attributes!]   = {'type' =>  'VirtualMachineRelocateSpec'}

$evm.log(:info, "vMotioning vm: #{vm.name} using bodyhash: #{body_hash}")
result = client.call(:relocate_vm_task, :message => body_hash)
$evm.log(:warn, "result body: #{result.body[:relocate_vm_task_response].inspect}")
$evm.log(:info, "result success?: #{result.success?}")

logout(client)
