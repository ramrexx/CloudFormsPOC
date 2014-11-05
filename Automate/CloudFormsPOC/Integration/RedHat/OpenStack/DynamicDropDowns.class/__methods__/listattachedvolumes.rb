begin

  def log(level, msg)
    @method = 'listUnattachedCinderVolumes'
    $evm.log(level, "#{@method}: #{msg}")
  end

  gem 'fog', '>=1.22.0'
  require 'fog'


  vm = $evm.root['vm']
  raise "VM is nil from $evm.root['vm']" if vm.nil?

  log(:info, "Found VM #{vm.name}")

  openstack = vm.ext_management_system

  log(:info, "Workin against OpenStack: #{openstack[:hostname]}")

  conn = Fog::Compute.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => "admin"
  })

  cinderconn = Fog::Volume.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => "admin"
  })

  log(:info, "Zeroing out existing Cinder custom attributes")
  num = 0
  while !vm.custom_get("CINDER_volume_#{num}").nil?
    vm.custom_set("CINDER_volume_#{num}", nil)
    num += 1
  end
  volume_hash = {}
  attachments = conn.get_server_details(vm.ems_ref).body['server']['os-extended-volumes:volumes_attached']
  log(:info, "Found volume attachments for #{vm.name}: #{attachments}")
  num = 0
  for attachment in attachments
    details = cinderconn.get_volume_details(attachment['id']).body['volume']
    volume_hash["#{details['display_name']}:#{details['attachments'][0]['device']}"] = attachment['id']
    vm.custom_set("CINDER_volume_#{num}", attachment['id'])
    log(:info, "Details for volume #{attachment['id']}: #{details.inspect}")
    num += 1
  end

  log(:info, "#{volume_hash.length}")
  if volume_hash.length <= 0
    log(:info, "No attached volumes on this host: #{attachments.inspect}")
    volume_hash["NO Volumes to Detach"] = "-1"
  end
  
  volume_hash[nil] = nil
  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = volume_hash
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")

rescue => err
  log(:error, "[#{err.class}:#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
