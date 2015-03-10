# delete_openstack_volumes.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to delete openstack volume(s) during retirement
#
# Inputs: vm.miq_provision.options[:created_volumes]
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
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
  vm     = $evm.root['vm']
  @task  = vm.miq_provision
  vendor = vm.vendor.downcase rescue nil

  if vendor == 'openstack'
    if @task
      log(:info, "Task id: #{@task.id} Request id: #{@task.miq_provision_request.id} Type: #{@task.provision_type}")
      template  = @task.vm_template
      provider  = template.ext_management_system

      created_volumes = @task.options[:created_volumes] || []
      log(:info, "created_volumes: #{created_volumes.inspect}")

      unless created_volumes.blank?
        tenant = get_tenant()
        openstack_volume = get_fog_object(provider, 'Volume', tenant.name)
        created_volumes.each do |volume_uuid|
          log(:info, "Checking status for volume: #{volume_uuid}", true)
          begin
            volume_details = openstack_volume.get_volume_details(volume_uuid).body['volume']
            log(:info, "Volume Details: #{volume_details.inspect}")
            log(:info, "Volume Status is #{volume_details['status']}", true)
            if volume_details['status'] == 'available'
              log(:info, "Deleting Volume: #{volume_uuid} on VM: #{vm.name}", true)
              openstack_volume.delete_volume(volume_uuid)
            end
            if volume_details['status'] == 'in-use'
              log(:warn, "Volume: #{volume_uuid} still attached", true)
            end
          rescue Fog::Compute::OpenStack::NotFound => gooderr
            log(:info, "Volume does not exist: #{gooderr}")
          end
        end
      end
    else
      log(:info, "VM: #{vm.name} missing miq_provision task")
    end
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
