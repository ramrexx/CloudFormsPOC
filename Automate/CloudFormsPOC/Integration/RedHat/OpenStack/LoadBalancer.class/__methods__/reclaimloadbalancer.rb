begin
  def log(level, msg)
    @method = 'reclaimLoadBalancer'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def remove_members(pool_id, netconn)
    log(:info, "Removing members from #{pool_id}")
    members = netconn.list_lb_members(:pool_id => pool_id)[:body]["members"]
    log(:info, "Members #{members.inspect}")
    for member in members
      log(:info, "Deleteing Member: #{member["id"]}")
      netconn.delete_lb_member(member["id"])
      log(:info, "Deleted member #{member["id"]}")
    end
    log(:info, "Done Removing members from #{pool_id}")
  end

  def remove_monitor(monitor_id, pool_id, netconn)
    log(:info, "Disassociating Monitor #{monitor_id} from #{pool_id}")
    netconn.disassociate_lb_health_monitor(pool_id, monitor_id)
    log(:info, "Disassociated #{monitor_id}")

    log(:info, "Deleting Monitor #{monitor_id}")
    begin
      netconn.delete_lb_health_monitor(monitor_id)
      log(:info, "Successfully deleted monitor #{monitor_id}")
    rescue lberr
      log(:error, "Error delete monitor #{monitor_id} #{lberr.class} [#{lberr}]")
      log(:error, "#{lberr.backtrace.join("\n")}")
      log(:error, "Continuing anyway")
    end
  end

  def remove_vip(vip_id, pool_id, netconn)
    log(:info, "Reclaiming VIP #{vip_id} from pool #{pool_id}")
    netconn.delete_lb_vip(vip_id)
    log(:info, "Deleted VIP #{vip_id}")
  end

  def remove_pool(pool_id, netconn)
    log(:info, "Cleaning up pool #{pool_id}")
    netconn.delete_lb_pool(pool_id)
    log(:info, "Deleted LB Pool #{pool_id}")
  end

  def return_floatingip(floatingip_id, netconn)
    log(:info, "Returning floating ip #{floatingip_id} to the available pool")
    netconn.delete_floating_ip(floatingip_id)
    log(:info, "Returned floating ip #{floatingip_id}")
  end

  log(:info, "Begin Automate Method")
  gem 'fog', '>=1.22.0'
  require 'fog'

  dump_root

  log(:info, "Service: #{$evm.root['service'].inspect}")

  service = $evm.root['service']

  raise "Unable to find service in $evm.root['service']" if service.nil?

  floatingip_id = service.custom_get("FLOATING_IP")
  pool_id = service.custom_get("POOL_ID")
  monitor_id = service.custom_get("MONITOR_ID")
  vip_id = service.custom_get("VIP_ID")

  tenant_tag = service.tags.select { 
    |tag_element| tag_element.starts_with?("cloud_tenants/")
    }.first.split("/", 2).last



  log(:info, "floatingip_id: #{floatingip_id rescue nil}")
  log(:info, "pool_id:       #{pool_id rescue nil}")
  log(:info, "monitor_id:    #{monitor_id rescue nil}")
  log(:info, "vip_id:        #{vip_id rescue nil}")
  log(:info, "tenant:        #{tenant_tag rescue nil}")

  # For now, let's just choose the first one.
  openstack = $evm.vmdb(:ems_openstack).all.first
  log(:info, "Logging with with tenant: #{tenant_tag}")
  netconn = Fog::Network.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant_tag
  })
  log(:info, "Logged into OpenStack successfully")

  remove_members(pool_id, netconn)
  remove_monitor(monitor_id, pool_id, netconn)
  remove_vip(vip_id, pool_id, netconn)
  remove_pool(pool_id, netconn)
  return_floatingip(floatingip_id, netconn) unless floatingip_id.blank?
  
  log(:info, "Removing Service from the VMDB")
  service.remove_from_vmdb
  log(:info, "End Automate Method")

rescue => err
  log(:error, "Unexpected Exception: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
