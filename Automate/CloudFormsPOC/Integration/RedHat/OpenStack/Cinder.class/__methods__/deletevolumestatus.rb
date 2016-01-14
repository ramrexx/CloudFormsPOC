begin

  def log(level, msg)
    @method = 'deleteVolumeStatus'
    $evm.log(level, "#{@method}: #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  gem 'fog', '>=1.22.0'
  require 'fog'

  log(:info, "Begin Automate Method")
  dump_root

  service = $evm.root['service']
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}>")

  raise "No Service found in $evm.root['service']" if service.nil?

  mid = service.custom_get("MID")
  volume_id = service.custom_get("VOLUME_ID")
  raise "Management System ID is nil" if mid.blank?

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?
  log(:info, "EMS_Openstack: #{openstack.inspect}\n#{openstack.methods.sort.inspect}")

  tenant_tag = service.tags.select { 
    |tag_element| tag_element.starts_with?("cloud_tenants/")
    }.first.split("/", 2).last

  log(:info, "Tenant is #{tenant_tag}")
              
  conn = Fog::Volume.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant_tag
  })

  log(:info, "Successfully connected to OpenStack EMS #{openstack.name} Volume Service")

  begin
    details = conn.get_volume_details(volume_id).body
    service.custom_set("STATUS","Volume Still Deleting #{details['volume']['status']}")
    log(:info, "Got Volume Details: #{details.inspect}")
    log(:info, "Volume still exists, sleeping")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "10.seconds"
    log(:info, "Exit Automate Method (Retry)")
    exit MIQ_OK
  rescue Fog::Compute::OpenStack::NotFound => gooderr
    log(:info, "Caught a NotFound erro #{gooderr}, volume is deleted")
    service.remove_from_vmdb
    log(:info, "Exit Automate Method (Done)")
    exit MIQ_OK
  end

rescue => err
  log(:error, "[#{err.class}:#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
