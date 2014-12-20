# Check_ReconfigVM_cpuHotAddEnabled.rb
#
# Description: This method checks to ensure that the VM's cpuHotAddEnabled has been set
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

def retry_method(retry_time, msg)
  $evm.log('info', "#{msg} - Waiting #{retry_time} seconds}")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

def get_vm_config_hash(client, vm)
  body_hash = {
    :_this  =>     "propertyCollector",
    :specSet   => {
      :propSet => {
        :type => "VirtualMachine",
        :pathSet => "config",
      },
      :objectSet => {
        :obj => vm.ems_ref,
        :skip => false,
        :attributes! => {  :obj =>  { 'type' => 'VirtualMachine' } }
      },
    },
    :options => {},
    :attributes! => {  :_this =>  { 'type' => 'PropertyCollector' } }
  }
  vm_config_result = client.call(:retrieve_properties_ex, message: body_hash).to_hash
  vm_config_hash = vm_config_result[:retrieve_properties_ex_response][:returnval][:objects][:prop_set][:val]
  return vm_config_hash
end

$evm.root.attributes.sort.each { |k, v| $evm.log(:info,"Root:<$evm.root> Attributes - #{k}: #{v}")}

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

if $evm.root['dialog_cpuhotaddenabled'].blank? || $evm.root['dialog_cpuhotaddenabled'] =~ (/(false|f|no|n|0)$/i)
  cpuHotAddEnabled = false
else
  cpuHotAddEnabled = true
end

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
vm_config_result = get_vm_config_hash(client, vm)
logout(client)

$evm.log('info', "vm_config_result cpuHotAddEnabled: #{cpuHotAddEnabled.inspect} vm_config_result[:cpu_hot_add_enabled]: #{vm_config_result[:cpu_hot_add_enabled].inspect}")
retry_method(15.seconds, "VM: #{vm.name} cpuHotAddEnabled: #{vm_config_result[:cpu_hot_add_enabled]} not changed") unless cpuHotAddEnabled == vm_config_result[:cpu_hot_add_enabled]
