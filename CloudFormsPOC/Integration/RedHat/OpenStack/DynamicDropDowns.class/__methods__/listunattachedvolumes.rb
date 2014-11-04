begin

  def log(level, msg)
    @method = 'listUnattachedCinderVolumes'
    $evm.log(level, "#{@method}: #{msg}")
  end

  gem 'fog', '>=1.22.0'
  require 'fog'


  vm = $evm.root['vm']
  raise "VM is nil from $evm.root['vm']" if vm.nil?

  log(:info, "Found VM #{vm.name}: #{vm.inspect}")

  openstack = vm.ext_management_system

  log(:info, "Working against OpenStack: #{openstack.inspect}")

  tenant_id = vm.cloud_tenant_id
  tenant_obj = $evm.vmdb(:cloud_tenant).find_by_id(tenant_id)
  log(:info, "VM is in tenant: #{tenant_obj.name}")


  conn = Fog::Volume.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant_obj.name
  })

  volumes = conn.list_volumes.body['volumes']
  volume_hash = {}
  for volume in volumes
    volume_hash["#{volume['display_name']} #{volume['size']}GB"] = "#{volume['id']}" if volume['status'] == "available"
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
