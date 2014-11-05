begin

  def log(level, msg)
    @method = 'deleteStackStatus'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def retire_service(service, openstack)
    log(:info, "Fully retiring service")
    service.remove_from_vmdb
    openstack.refresh
    log(:info, "Retired")
  end

  log(:info, "Begin Automate Method")

  gem 'fog', '>=1.22.0'
  require 'fog'

  dump_root
  service = $evm.root['service']
  raise "Service cannot be nil" if service.nil?

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
    log(:error, "Did not find stack with id #{stack_id}, already deleted?")
    retire_service(service, openstack) if $evm.object['retireOnDelete']
    exit MIQ_OK
  end

  log(:info, "Found Stack #{stack.stack_status} #{stack.inspect}")
  if stack.stack_status == "DELETE_COMPLETE"
    service.custom_set("STATUS", "SUCCESS: #{stack.stack_status}")
    log(:info, "Stack Delete is complete")
  elsif stack.stack_status == "DELETE_FAILED"
    log(:error, "Stack creation failed: #{stack.stack_status_reason} #{stack.inspect}")
    log(:error, "Attempting another delete, this may require manual intervention")
    response = conn.delete_stack(stack.stack_name, stack.stack_id)
    log(:info, "Delete Response #{response.inspect}")
    log(:info, "Sleeping")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  else
    service.custom_set("STATUS", "IN PROGRESS #{stack.stack_status}")
    log(:info, "Sleeping for 1 minute")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

  retire_service(service, openstack) if $evm.object['retireOnDelete']

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
