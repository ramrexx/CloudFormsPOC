begin

  def log(level, msg)
    @method = 'detachVolume'
    $evm.log(level, "#{@method}: #{msg}")
  end

  gem 'fog', '>=1.22.0'
  require 'fog'

  vm = $evm.root['vm']
  raise "VM is nil from $evm.root['vm']" if vm.nil?

  if vm.tagged_with?("cinder", "locked_volumes")
    log(:error, "VM is tagged with cinder/locked_volumes, this operation is denied")
    exit MIQ_ABORT
  end

  log(:info, "Found VM #{vm.name}")

  openstack = vm.ext_management_system
  log(:info, "Found OpenStack #{openstack[:hostname]}")

  volume_id = $evm.root['dialog_volume_id']
  log(:info, "Detaching volume #{volume_id} from vm #{vm.ems_ref}")

  cinderconn = Fog::Volume.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => "admin"
  })
  log(:info, "Successfully connected to OpenStack Volume service at #{openstack[:hostname]}")

  conn = Fog::Compute.new ({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => "admin"
  })
  log(:info, "Successfully connected to OpenStack Compute service at #{openstack[:hostname]}")

  details = cinderconn.get_volume_details(volume_id).body['volume']
  log(:info, "Got volume details: #{details.inspect}")
  attachments = details['attachments']
  for attachment in attachments
    log(:info, "Checking #{attachment.inspect}")
    if attachment['id'] == volume_id
      response = conn.detach_volume(vm.ems_ref, attachment['id'])
      log(:info, "Detach volume response: #{response.inspect}")
    else
      log(:info, "Skipping #{attachment.inspect} because it doesn't match #{volume_id}")
    end
  end

  # Clean up custom attributes
  num = 0
  while !vm.custom_get("CINDER_volume_#{num}").nil?
    vm.custom_set("CINDER_volume_#{num}", nil)
    num += 1
  end
  num = 0
  attachments = conn.get_server_details(vm.ems_ref).body['server']['os-extended-volumes:volumes_attached']
  for attachment in attachments
    unless attachment['id'] == volume_id
      vm.custom_set("CINDER_volume_#{num}", attachment['id'])
      log(:info, "Set custom attr CINDER_volume_#{num} = #{attachment['id']}")
      num += 1
    end
  end

  exit MIQ_OK

rescue => err
  log(:error, "[#{err.class}:#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
