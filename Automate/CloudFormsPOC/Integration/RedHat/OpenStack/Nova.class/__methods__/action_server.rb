##################################################
#
# CFME Automate Method: action_server
#
# by Marco Berube
#
# Note:  Action a server with one of the following command:
#        start_server, stop_server, pause_server, unpause_server, suspend_server, resume_server
#
##################################################
begin

  def log(level, msg)
    @method = 'action_server'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  #dump_root

  require 'fog'
  
  vm = nil
  case $evm.root['vmdb_object_type']
    when 'vm'
      vm = $evm.root['vm']
  end

  raise "VM is nil" if vm.nil?
  
  log(:info, "Nova instance UUID is #{vm.ems_ref}")
  instance_uuid = vm.ems_ref
  
  action = nil
  action ||= $evm.root['action']
  log(:info, "Fog action: #{action}")
  
  raise "Action is nil, you must provide action" if action.nil?
  
  
  # GET OPENSTACK PROVIDER DETAILS
  openstack = vm.ext_management_system
  #log(:info, "OpenStack #{openstack.inspect}")
  #log(:info, ":openstack_username:   #{openstack.authentication_userid.inspect}")
  #log(:info, ":openstack_auth_url:  http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens")

  # CONNECT TO OPENSTACK PROVIDER
  conn = Fog::Compute.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => "admin"
  })

  #log(:info, "Got connection #{conn.class} #{conn.inspect}")    
    
	case action
    when "start_server"
      raise "Fog error on selected action: #{action}" unless conn.start_server("#{instance_uuid}")
    when "stop_server"
      raise "Fog error on selected action: #{action}" unless conn.stop_server("#{instance_uuid}")
    when "pause_server"
      raise "Fog error on selected action: #{action}" unless conn.pause_server("#{instance_uuid}")
    when "unpause_server"
      raise "Fog error on selected action: #{action}" unless conn.unpause_server("#{instance_uuid}")
    when "suspend_server"
      raise "Fog error on selected action: #{action}" unless conn.suspend_server("#{instance_uuid}")
    when "resume_server"
   	  raise "Fog error on selected action: #{action}" unless conn.resume_server("#{instance_uuid}")
    else
      raise "No server action provided."
    end

	log(:info, "instance uuid=#{instance_uuid} has succesfully run the following action: #{action}")

  vm.refresh
  openstack.refresh  

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
