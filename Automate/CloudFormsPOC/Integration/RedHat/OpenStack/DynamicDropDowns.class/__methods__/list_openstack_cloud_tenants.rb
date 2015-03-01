# list_openstack_cloud_tenants.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List Cloud Tenant ids by provider
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  def get_provider(provider_id=nil)
    $evm.root.attributes.detect { |k,v| provider_id = v if k.end_with?('provider_id') } rescue nil
    provider = $evm.vmdb(:ems_openstack).find_by_id(provider_id)
    log(:info, "Found provider: #{provider.name} via provider_id: #{provider.id}") if provider

    # set to true to default to the admin tenant
    use_default = false
    unless provider
      # default the provider to first openstack provider
      provider = $evm.vmdb(:ems_openstack).first if use_default
      log(:info, "Found openstack: #{provider.name} via default method") if provider && use_default
    end
    provider ? (return provider) : (return nil)
  end

  def get_tenant(tenant_category, tenant_id=nil)
    # get the cloud_tenant id from $evm.root if already set
    $evm.root.attributes.detect { |k,v| tenant_id = v if k.end_with?('cloud_tenant') } rescue nil
    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_id)
    log(:info, "Found tenant: #{tenant.name} via tenant_id: #{tenant.id}") if tenant

    unless tenant
      # get the tenant name from the group tenant tag
      group = $evm.root['user'].current_group
      tenant_tag = group.tags(tenant_category).first rescue nil
      tenant = $evm.vmdb(:cloud_tenant).find_by_name(tenant_tag) rescue nil
      log(:info, "Found tenant: #{tenant.name} via group: #{group.description} tagged_with: #{tenant_tag}") if tenant
    end

    # set to true to default to the admin tenant
    use_default = false
    unless tenant
      tenant = $evm.vmdb(:cloud_tenant).find_by_name('admin') if use_default
      log(:info, "Found tenant: #{tenant.name} via default method") if tenant && use_default
    end
    tenant ? (return tenant) : (return nil)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  provider = get_provider()

  dialog_hash = {}

  if provider
    # only list tenants from the provider object
    provider.cloud_tenants.each do |ct|
      log(:info, "Looking at tenant: #{ct.name} ems_ref: #{ct.ems_ref}")
      dialog_hash[ct.id] = "#{ct.name} on #{provider.name}"
    end
  else
    tenant_category = $evm.object['tenant_category'] || 'tenant'
    tenant = get_tenant(tenant_category)

    $evm.vmdb(:cloud_tenant).all.each do |ct|
      log(:info, "Looking at tenant: #{ct.name} id: #{ct.id} ems_ref: #{ct.ems_ref}")
      next unless ct.ext_management_system
      if tenant.respond_to?('name')
        # if a tenant is found use the name to filter the cloud_tenants
        if ct.name == "#{tenant.name}"
          dialog_hash[ct.id] = "#{ct.name} in #{ct.ext_management_system.name}"
        end
      else
        # if no tenant is found build a list of all cloud_tenants
        dialog_hash[ct.id] = "#{ct.name} in #{ct.ext_management_system.name}"
      end
    end
  end

  if dialog_hash.blank?
    log(:info, "User has no access to tenants")
    dialog_hash[nil] = "< No Tenant Access, Contact Administrator >"
  else
      dialog_hash[nil] = '< choose a tenant >'
  end

  $evm.object['values'] = dialog_hash
  log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "#{err.class} #{err}")
  log(:error, "#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
