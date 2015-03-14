# MarkVMAsVirtualMachine.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method marks a VMware template as a VM
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

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
      log(:error, "Error logging out #{logouterr.class} #{logouterr}")
    end
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get vm object from root
  vm = $evm.root['vm']
  raise "VM object not found" if vm.nil?

  # This method only works with VMware VMs currently
  raise "Invalid vendor: #{vm.vendor}" unless vm.vendor.downcase == 'vmware'

  log(:info, "Detected VM: #{vm.name} vendor: #{vm.vendor} provider: #{vm.ext_management_system.name} ems_ref: #{vm.ems_ref}")

  # get resource_pool.ems_ref from root
  resource_pool = $evm.root['dialog_resource_pool']

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
  log(:info, "mark_as_virtual_machine_result success?: #{mark_as_virtual_machine_result.success?}")

  logout(client)

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
