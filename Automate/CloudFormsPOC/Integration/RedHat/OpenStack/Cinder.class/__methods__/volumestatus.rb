begin

  def log(level, msg)
    @method = 'volumeStatus'
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

  service_template_provision_task = $evm.root['service_template_provision_task']
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")
  log(:info, "DEBUG: #{service_template_provision_task.inspect}")

  mid = service_template_provision_task.get_option(:mid)
  volume_id = service_template_provision_task.get_option(:volume_id)
  tenant_name = service_template_provision_task.get_option(:tenant_name)

  log(:info, "MID: #{mid} Volume ID: #{volume_id}")

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?
              
  conn = Fog::Volume.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant_name
  })

  log(:info, "Successfully connected to OpenStack EMS #{openstack.name} Volume Service")

  details = conn.get_volume_details(volume_id).body['volume']
  log(:info, "Got Volume Details: #{details.inspect}")

  if details['status'] == "available"
    log(:info, "Volume is available, finishing")
    exit MIQ_OK
  elsif details['status'] == "in-use"
    log(:info, "Volume is now attached, odd, but OK #{details.inspect}")
    exit MIQ_OK
  else
    service_template_provision_task.message = "Volume Creation IN PROGRESS #{details['status']}"
    log(:info, "Sleeping for 30 seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "10.seconds"
    exit MIQ_OK
  end

rescue => err
  log(:error, "[#{err.class}:#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
