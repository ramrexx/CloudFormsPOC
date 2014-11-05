begin

  def log(level, msg)
    @method = 'retireStack'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  
  def retire_service(service)
  	log(:info, "Retiring #{service.name}")
  	service.retire_now
  	log(:info, "Removing #{service.name} from vmdb")
  	service.remove_from_vmdb
  end

  gem 'fog', '>=1.22.0'
  require 'fog'

  dump_root

  service = $evm.root['service']
  raise "Service cannot be nil" if service.nil?
    
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}>")

  mid = service.custom_get("MID")
  stack_id = service.custom_get("STACK_ID")

  log(:info, "MID: #{mid} Stack ID: #{stack_id}")

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?

  tenant_tag = service.tags.select { 
    |tag_element| tag_element.starts_with?("cloud_tenants/")
    }.first.split("/", 2).last

    log(:info, "Tenant is #{tenant_tag}")
              
  conn = Fog::Orchestration.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant_tag
  })

  log(:info, "Successfully connected to OpenStack EMS #{openstack.name} Orchestration Service")
  stack = conn.stacks.find_by_id(stack_id)

  if stack.nil?
    log(:error, "Did not find stack with id #{stack_id} in tenant #{tenant_tag}")
    retire_service(service)
    exit MIQ_OK
  end

  response = conn.delete_stack(stack.stack_name, stack.id)
  log(:info, "Initiated Stack Delete: #{response.inspect}")
  service.custom_set("STATUS", "DELETE IN PROGRESS")

  exit MIQ_OK


rescue => err
  log(:error, "Error retiring service [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT

end
