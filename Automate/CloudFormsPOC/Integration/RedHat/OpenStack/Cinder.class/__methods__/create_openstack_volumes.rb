# create_openstack_volumes.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to create openstack volume(s) during provisioning
#
# Input exmaple1: volume_0_size =>20, volume_1_size=>50 (create a bootable 20GB volume based on template and add an additional 50 empty volume)
# Input exmaple2: volume_0_size =>0, volume_1_size=>50 (simply clones the template (ephemeral) and adds an additional 50 empty volume)
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

  # look in options and ws_values hash that start with "volume_[0-9]"
  def parse_openstack_volume_cloning_options()
    log(:info, "Processing parse_openstack_volume_cloning_options...", true)
    ws_values = @task.options.fetch(:ws_values, {})
    volume_options_hash, volume_ws_values_hash, volume_hash = {}, {}, {}
    volume_regex = /^volume_(\d*)_(.*)/

    # loop through task options for volume matching parameters
    @task.options.each do |k, value|
      next if value.blank?
      if volume_regex =~ k
        boot_index, paramter = $1.to_i, $2.to_sym
        log(:info, "boot_index: #{boot_index} - Adding option: {#{paramter.inspect} => #{value.inspect}} to volume_options_hash")
        (volume_options_hash[boot_index] ||={})[paramter] = value
      end
    end
    # loop through ws_values for volume matching parameters
    ws_values.each do |k, value|
      next if value.blank?
      if volume_regex =~ k
        boot_index, paramter = $1.to_i, $2.to_sym
        log(:info, "boot_index: #{boot_index} - Adding option: {#{paramter.inspect} => #{value.inspect}} to volume_ws_values_hash")
        (volume_ws_values_hash[boot_index] ||={})[paramter] = value
      end
    end
    volume_hash = volume_options_hash.merge(volume_ws_values_hash) if volume_options_hash
    log(:info, "Inspecting volume_hash: #{volume_hash.inspect}")
    log(:info, "Processing parse_openstack_volume_cloning_options...Complete", true)
    return volume_hash
  end

  def get_fog_object(ems_openstack, type="Compute", tenant='admin', auth_token=nil, encrypted=false, verify_peer=false)
    encrypted ? (proto = "https") : (proto = "http")
    require 'fog'
    begin
      return Object::const_get("Fog").const_get("#{type}").new(
        {
          :provider => "OpenStack",
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

  log(:info, "Task id: <#{@task.id}> Request id: #{@task.miq_provision_request.id} Type: #{@task.provision_type}")

  created_volumes = []

  volume_hash = parse_openstack_volume_cloning_options()
  unless volume_hash.blank?
    tenant = get_tenant()
    openstack_volume = get_fog_object(provider, "Volume", tenant.name)

    volume_hash.each do |boot_index, volume_options|
      # check boot_index and size
      if boot_index.zero?
        if volume_options[:size].to_i.zero?
          log(:info, "Boot disk is ephemeral, skipping volume... ")
          volume_options[:size] = 0
        else
          volume_options[:bootable] = true
          volume_options[:imageref] = template.ems_ref
        end
      else
        volume_options[:bootable] = false
        volume_options[:imageref] = ''
      end
      unless volume_options[:size].to_i.zero?
        volume_options[:name]         = "CloudForms created volume #{boot_index} for #{@task.get_option(:vm_target_name)}"
        volume_options[:description]  = "#{volume_options[:name]} at #{Time.now}"
        log(:info, "Creating volume #{volume_options[:name]}/#{volume_options[:description]} of size #{volume_options[:size]}GB", true)
        new_volume = openstack_volume.create_volume(volume_options[:name], volume_options[:description], volume_options[:size], { :bootable => volume_options[:bootable], :imageRef => volume_options[:imageref] }).body['volume']
        log(:info, "Successfully created volume #{boot_index}: #{new_volume['id']}", true)
        volume_options[:uuid] = new_volume['id']
        created_volumes << new_volume['id']
      end
    end
    unless volume_hash.blank?
      @task.set_option(:volume_hash, volume_hash)
      @task.set_option(:created_volumes, created_volumes)
      log(:info, "volume_hash: #{@task.options[:volume_hash].inspect}")
      log(:info, "created_volumes: #{@task.options[:created_volumes].inspect}")
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
  @task.finished("#{err}") if @task && @task.respond_to?('finished')
  exit MIQ_ABORT
end
