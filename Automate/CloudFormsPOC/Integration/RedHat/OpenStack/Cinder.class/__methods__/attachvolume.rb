begin

  def log(level, msg)
    @method = 'attachVolume'
    $evm.log(level, "#{@method}: #{msg}")
  end

  gem 'fog', '>=1.22.0'
  require 'fog'

  vm = $evm.root['vm']
  raise "VM is nil from $evm.root['vm']" if vm.nil?

  log(:info, "Found VM #{vm.name}: #{vm.inspect}")

  openstack = vm.ext_management_system
  log(:info, "Found OpenStack #{openstack.inspect}")

  volume_id = $evm.root['dialog_volume_id']
  log(:info, "Attaching volume #{volume_id} to vm #{vm.ems_ref}")

  tenant_id = vm.cloud_tenant_id
  tenant_obj = $evm.vmdb(:cloud_tenant).find_by_id(tenant_id)
  log(:info, "VM is in tenant: #{tenant_obj.name}")

  conn = Fog::Compute.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant_obj.name
  })

  log(:info, "Successfully connected to OpenStack compute service at #{openstack[:hostname]}")
  details = conn.get_server_details(vm.ems_ref).body['server']
  log(:info, "Got server details from OpenStack: #{details.inspect}")
  volumes = details['os-extended-volumes:volumes_attached']
  log(:info, "Volumes attached to this server: #{volumes.inspect}")
  num = 0
  for volume in volumes
  	vm.custom_set("CINDER_volume_#{num}", volume['id'])
  	num += 1
  end

  response = conn.attach_volume(volume_id, vm.ems_ref, nil)
  log(:info, "Volume Attach Response: #{response.inspect}")
  vm.custom_set("CINDER_volume_#{num}", "#{volume_id}")
  exit MIQ_OK

rescue => err
  log(:error, "[#{err.class}:#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
