# ListTenantNetworks.rb
#
# Description: List Tenant Networks in OpenStack
#

def get_tenant
  tenant_ems_id = $evm.root['dialog_cloud_tenant']
  $evm.log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
  return tenant_ems_id if tenant_ems_id.nil?

  tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
  $evm.log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.name} ems_ref: #{tenant.ems_ref}")
  return tenant
end

$evm.root.attributes.sort.each { |k,v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }

tenant = get_tenant

$evm.log(:info, "Found Tenant #{tenant.name}")

provider_id = $evm.root['dialog_mid']
provider = $evm.vmdb(:ems_openstack).find_by_id(provider_id)
provider ||= $evm.vmdb(:ems_openstack).all.first

$evm.log(:info, "Working in provider: #{provider.name} id: #{provider.id}")

networks_hash = {}
provider.cloud_networks.each do |network|
  $evm.log(:info, "Found Network: #{network.name} ems_ref: #{network.ems_ref}")
  networks_hash[network.ems_ref] = "#{network.name} in #{tenant.name}" if network.cloud_tenant_id == tenant.id
end
networks_hash[nil] = nil

$evm.object['values'] = networks_hash

$evm.log(:info, "Dropdown Values Are #{$evm.object['values'].inspect}")
