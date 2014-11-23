# ListGlanceTemplates.rb
#
# Description: List Glance Templates in OpenStack
#

def get_tenant
  tenant_ems_id = $evm.root['dialog_cloud_tenant']
  $evm.log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
  return tenant_ems_id if tenant_ems_id.nil?

  tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
  $evm.log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
  
    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)

  return tenant
end

$evm.root.attributes.sort.each { |k,v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }

tenant = get_tenant

$evm.log(:info, "Found Tenant #{tenant.name rescue "admin"}")

provider_id = $evm.root['dialog_mid']
provider = $evm.vmdb(:ems_openstack).find_by_id(provider_id)
provider ||= $evm.vmdb(:ems_openstack).all.first

$evm.log(:info, "Working in provider: #{provider.name} id: #{provider.id}")

template_hash = {}
template_hash[nil] = nil

$evm.vmdb(:template_openstack).all.each do |template|
  $evm.log(:info, "Found Template: #{template.name} ems_ref: #{template.ems_ref}")
  next unless template.ems_id == provider.id
  (template_hash||={})[template.ems_ref] = template.name if template.cloud_tenant_id == tenant.id || template.publicly_available
end

$evm.object['values'] = template_hash

$evm.log(:info, "Dropdown Values Are #{$evm.object['values'].inspect}")
