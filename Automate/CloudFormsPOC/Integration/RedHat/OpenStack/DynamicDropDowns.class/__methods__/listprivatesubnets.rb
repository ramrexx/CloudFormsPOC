# listPrivateSubnets.rb
#
# Description: List private Subnets in OpenStack
#
def list_private_subnets(conn, tenant_id)
  return conn.networks.select {
    |network| network.tenant_id.to_s == "#{tenant_id}" && network.router_external == false
  }
end

def get_tenant
  tenant_ems_id = $evm.root['dialog_cloud_tenant']
  $evm.log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
  return tenant_ems_id if tenant_ems_id.nil?

  tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
  $evm.log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
  return tenant
end

$evm.root.attributes.sort.each { |k,v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }

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
$evm.log(:info, "Got tenant name #{tenant.name}/#{tenant.ems_ref}")
subnet_hash = {}
unless tenant.nil?
  $evm.log(:info, "Logging into OpenStack under tenant #{tenant}")
  conn = Fog::Network.new({
                            :provider => 'OpenStack',
                            :openstack_api_key => openstack.authentication_password,
                            :openstack_username => openstack.authentication_userid,
                            :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
                            :openstack_tenant => tenant.name
  })

  subnets = list_private_subnets(conn, tenant.ems_ref)
  for subnet in subnets
    $evm.log(:info, "On subnet #{subnet.inspect}")
    subnet_hash[subnet.subnets.first.id] = "#{subnet.subnets.first.cidr} in #{tenant.name}"
    $evm.log(:info, "Adding #{subnet.subnets.first.cidr} to the hash for #{subnet.subnets.first.inspect}")
  end
  subnet_hash[nil] = "No Networks Available in Tenant #{tenant.name}" if subnets.length == 0
else
  subnet_hash[nil] = "No Tenant Selected, Select a Tenant First"
end

subnet_hash[nil] = nil

$evm.object['values'] = subnet_hash
$evm.object['default_value'] = subnet_hash.first[0]
$evm.log(:info, "Default is #{subnet_hash.first[1]}/#{$evm.object['default_value']}")
$evm.log(:info, "Dynamic drop down values: #{$evm.object['values']}")
