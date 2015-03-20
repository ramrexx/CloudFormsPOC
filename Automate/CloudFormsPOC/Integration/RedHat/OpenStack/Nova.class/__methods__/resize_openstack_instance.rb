# resize_openstack_instance.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to change the flavor of an openstack instance. Note that flavors can only be increased
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

  def set_ae_options_hash(hash)
    log(:info, "Adding {#{hash}} to ae_workspace: #{@ae_state_var}", true)
    $evm.set_state_var(@state_var, hash)
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

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  vm  = $evm.root['vm']
  raise "vm not found" if vm.nil?
  log(:info, "Found VM: #{vm.name} vendor: #{vm.vendor} ")

  if vm.vendor.downcase == 'openstack'
    provider  = vm.ext_management_system
    original_flavor = vm.flavor
    dialog_flavor = $evm.root['dialog_flavor']
    new_flavor = $evm.vmdb(:flavor_openstack).find_by_id(dialog_flavor) || $evm.vmdb(:flavor_openstack).find_by_name(dialog_flavor)
    tenant = $evm.vmdb(:cloud_tenant).find_by_id(vm.cloud_tenant_id)

    # $evm.set_state_var(:original_flavor_id, vm.flavor_id)
    log(:info, "VM: #{vm.name} ems_ref: #{vm.ems_ref} tenant id: #{vm.cloud_tenant_id} original_flavor: #{original_flavor.name} new_flavor: #{new_flavor.name}")
    openstack_compute = get_fog_object(provider, "Compute", tenant.name)
    log(:info, "Resizing VM: #{vm.name} to #{new_flavor.name}")
    resize_details = openstack_compute.resize_server(vm.ems_ref, new_flavor.ems_ref)
    log(:info, "resize_details: #{resize_details.inspect}")
    vm_details = openstack_compute.get_server_details(vm.ems_ref)
    log(:info, "vm_details: #{vm_details.inspect}")
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
  exit MIQ_ABORT
end
