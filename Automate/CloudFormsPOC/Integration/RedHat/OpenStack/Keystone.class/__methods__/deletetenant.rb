
begin

  def log(level, msg)
    @method = 'deleteTenant'
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

  mid = mid = service.custom_get("MID")
  tenant_id = service.custom_get("TENANT_ID")

  raise "MID is nil, cannot continue" if mid.nil?

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?

  raise "No tenant ID available from service.custom_get: #{tenant_id}" if tenant_id.nil?

  log(:info, "Connecting to OpenStack EMS #{openstack[:hostname]}/#{mid}")
  conn = nil
  # Get a connection as "admin" to Keystone 
  begin
    conn = Fog::Identity.new({
      :provider => 'OpenStack',
      :openstack_api_key => openstack.authentication_password,
      :openstack_username => openstack.authentication_userid,
      :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
      :openstack_tenant => "admin"
    })
  rescue => connerr
    log(:error, "Retryable connection error #{connerr}")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

  log(:info, "Deleting Tenant #{tenant_id} from OpenStack")

  response = conn.delete_tenant(tenant_id)
  log(:info, "Delete Response #{response.inspect}")

  retire_service(service, openstack)
  log(:info, "End Automate Method")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'Error'
  task = $evm.root['service_template_provision_task']
  unless task.nil?
    task.destination.remove_from_vmdb
  end
  log(:error, "Removing failed service from VMDB")
  exit MIQ_ABORT
end
