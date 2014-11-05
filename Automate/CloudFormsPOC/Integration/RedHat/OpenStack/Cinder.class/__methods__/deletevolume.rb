begin

  def log(level, msg)
    @method = 'deleteVolume'
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

  log(:info, "Successfully connected to Storage Service at #{openstack.name}")
  log(:info, "Deleting Volume with id #{volume_id}")

  begin
    details = conn.get_volume_details(volume_id).body
    log(:info, "Found Volume: #{details.inspect}")
    if details['volume']['status'] == "in-use"
      log(:error, "Error, volume is still attached.  Raising exception: #{details.inspect}")
      raise "Error, Volume is attached, cannot delete it"
    end
  rescue Fog::Compute::OpenStack::NotFound => gooderr
  	log(:info, "Volume apparently does not exit: #{gooderr}")
  	exit MIQ_OK
  end

  response = conn.delete_volume(volume_id)
  log(:info, "Initiated Volume Delete: #{response.inspect}")
  exit MIQ_OK

rescue => err
  log(:error, "Uncaught Error [#{err.class}:#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
