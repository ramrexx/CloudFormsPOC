###################################
#
# CFME Automate Method: Satellite5_GetSystemID
#
#
# Notes: This method gets a VM system id from Satellite v5
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'Satellite5_GetSystemID'
    $evm.log(level, "#{@method}: #{message}")
  end

  log(:info, "CFME Automate Method Started")

  # Dump all root attributes
  log(:info, "Listing Root Object Attributes:")
  $evm.root.attributes.sort.each { |k, v| log(:info, "\t#{k}: #{v}") }
  log(:info, "===========================================")

  # Get vm object from the VM class versus the VmOrTemplate class for vm.remove_from_service to work
  vm = $evm.vmdb("vm", $evm.root['vm_id'])
  raise "$evm.root['vm'] not found" if vm.nil?
  log(:info, "Found VM:<#{vm.name}>")

  # Get Satellite server from model else set it here
  satellite = nil
  satellite ||= $evm.object['servername']

  # Get Satellite url from model else set it here
  satellite_url = "/rpc/api"
  satellite_url ||= $evm.object['serverurl']

  # Get Satellite username from model else set it here
  username = nil
  username ||= $evm.object['username']

  # Get Satellite password from model else set it here
  password = nil
  password ||= $evm.object.decrypt('password')

  # Require CFME rubygems and xmlrpc/client
  require "rubygems"
  require "xmlrpc/client"

  xmlrpc_client = XMLRPC::Client.new(satellite, satellite_url)
  log(:info, "xmlrpc_client: #{xmlrpc_client.inspect}")

  xmlrpc_key = xmlrpc_client.call('auth.login', username, password)
  log(:info, "xmlrpc_key: #{xmlrpc_key.inspect}")

  #get the system id
  satellite_getsysid = xmlrpc_client.call('system.getId', xmlrpc_key, vm.name)
  log(:info, "satellite_getsysid: #{satellite_getsysid.inspect}")
  
  satellite_systemid = satellite_getsysid[0]["id"]
  log(:info, "satellite_getsysid: #{satellite_systemid.inspect}")

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
