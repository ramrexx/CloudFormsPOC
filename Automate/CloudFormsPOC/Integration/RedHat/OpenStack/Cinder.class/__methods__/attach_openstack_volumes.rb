# attach_openstack_volumes.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to attach openstack volume(s) after an ephemeral ( clone from template ) during post provisioning. This method must be run after CheckProvisioned
#
# Inputs: @task.options[:created_volumes]
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
    @task.message = msg if @task.respond_to?('message') && update_message
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  def retry_method(retry_time, msg='INFO')
    log(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def get_fog_object(ems_openstack, type='Compute', tenant='admin', auth_token=nil, encrypted=false, verify_peer=false)
    encrypted ? (proto = 'https') : (proto = 'http')
    require 'fog'
    begin
      return Object::const_get("Fog").const_get("#{type}").new(
        {
          :provider => 'OpenStack',
          :openstack_api_key => ems_openstack.authentication_password,
          :openstack_username => ems_openstack.authentication_userid,
          :openstack_auth_url => "#{proto}://#{ems_openstack[:ipaddress]}:#{ems_openstack[:port]}/v2.0/tokens",
          :openstack_auth_token => auth_token,
          :connection_options => { :ssl_verify_peer => verify_peer, :ssl_version => :TLSv1 },
          :openstack_tenant => tenant
      })
    rescue Excon::Errors::SocketError => sockerr
      raise unless sockerr.message.include?("end of file reached (EOFError)")
      log(:error, "Looks like potentially an ssl connection due to error: #{sockerr}")
      return get_fog_object(ems_openstack, type, tenant, auth_token, true, verify_peer)
    rescue => loginerr
      log(:error, "Error logging #{loginerr} - [#{ems_openstack}, #{type}, #{tenant}, #{auth_token rescue "NO TOKEN"}]")
      log(:error, "Returning nil")
    end
    return nil
  end

  def get_tenant()
    ws_values = @task.options.fetch(:ws_values, {})
    tenant_id = @task.get_option(:cloud_tenant_id) || ws_values[:cloud_tenant_id] rescue nil
    tenant_id ||= @task.get_option(:cloud_tenant) || ws_values[:cloud_tenant] rescue nil
    unless tenant_id.nil?
      tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_id)
      log(:info, "Using tenant: #{tenant.name} id: #{tenant.id} ems_ref: #{tenant.ems_ref}")
    else
      tenant = $evm.vmdb(:cloud_tenant).find_by_name('admin')
      log(:info, "Using default tenant: #{tenant.name} id: #{tenant.id} ems_ref: #{tenant.ems_ref}")
    end
    return tenant
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get provisioning object
  @task     = $evm.root['miq_provision']
  template  = @task.vm_template
  provider  = template.ext_management_system

  log(:info, "Task id: #{@task.id} Request id: #{@task.miq_provision_request.id} Type: #{@task.provision_type}")

  vm = @task.vm
  retry_method(15.seconds, "Waiting for VM: #{@task.get_option(:vm_target_name)}") if vm.nil?

  created_volumes = @task.options[:created_volumes] || []
  log(:info, "created_volumes: #{created_volumes.inspect}")

  unless created_volumes.blank?
    tenant = get_tenant()
    openstack_compute = get_fog_object(provider, 'Compute', tenant.name)
    created_volumes.each do |volume_uuid|
      log(:info, "Checking status for volume: #{volume_uuid}", true)
      volume_details = openstack_compute.get_volume_details(volume_uuid).body['volume']
      log(:info, "Volume Details: #{volume_details.inspect}")
      log(:info, "Volume Status is #{volume_details['status']}", true)
      if volume_details['status'] == "available"
        log(:info, "Attaching Volume: #{volume_uuid} to VM: #{vm.name}", true)
        openstack_compute.attach_volume(volume_uuid, vm.ems_ref, nil)
      else
        log(:info, "Volume: #{volume_uuid} already in-use", true)
      end
    end
    vm.refresh
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task && @task.respond_to?('finished')
  exit MIQ_ABORT
end
