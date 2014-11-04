begin

  def log(level, msg)
    @method = 'listPrivateSubnets'
    $evm.log(level, "#{@method}: #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k,v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def list_private_subnets(conn, tenant_id)
    return conn.networks.select {
      |network| network.tenant_id.to_s == "#{tenant_id}" && network.router_external == false
    }
  end

  def get_tenant
    tenant_ems_id = $evm.root['dialog_cloud_tenant']
    log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
    return tenant_ems_id if tenant_ems_id.nil?

    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
    log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
    return tenant
  end
  log(:info, "Automate Method Started")

  dump_root

  gem 'fog', '>=1.22.0'
  require 'fog'

  name = nil

  name = $evm.object['ems_openstack_name']
  openstack = nil
  if name.nil?
  	openstack = $evm.vmdb(:ems_openstack).all.first
  else
    openstack = $evm.vmdb(:ems_openstack).find_by_name("#{name}")
  end

  raise "No openstack EMS found" if openstack.nil?

  tenant = get_tenant
  log(:info, "Got tenant name #{tenant.name}/#{tenant.ems_ref}")
  subnet_hash = {}
  unless tenant.nil?
    log(:info, "Logging into OpenStack under tenant #{tenant}")
    conn = Fog::Network.new({
      :provider => 'OpenStack',
      :openstack_api_key => openstack.authentication_password,
      :openstack_username => openstack.authentication_userid,
      :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
      :openstack_tenant => tenant.name
    })

    subnets = list_private_subnets(conn, tenant.ems_ref)
    for subnet in subnets
      log(:info, "On subnet #{subnet.inspect}")
    	subnet_hash["#{subnet.subnets.first.cidr} in #{tenant.name}"] = "#{subnet.subnets.first.id}"
    	log(:info, "Adding #{subnet.subnets.first.cidr} to the hash for #{subnet.subnets.first.inspect}")
    end
    subnet_hash["No Networks Available in Tenant #{tenant.name}"] = nil if subnets.length == 0
  else
    subnet_hash["No Tenant Selected, Select a Tenant First"] = nil
  end

  subnet_hash[nil] = nil

  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = subnet_hash
  $evm.object['default_value'] = subnet_hash.first[0]
  log(:info, "Default is #{subnet_hash.first[1]}/#{$evm.object['default_value']}")
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")

  log(:info, "Automate Method Ended")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
