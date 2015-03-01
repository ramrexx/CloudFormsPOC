# list_openstack_providers.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List OpenStack Provider ids
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

  tenant_category = $evm.object['tenant_category'] || 'tenant'
  tenant = get_tenant(tenant_category)

  dialog_hash = {}

  if tenant
    ems_openstack = $evm.vmdb(:ems_openstack).find_by_id(tenant.ems_id)
    dialog_hash[ems_openstack.id] = ems_openstack.name if ems_openstack
  else
    $evm.vmdb(:ems_openstack).all.each do |ems|
      dialog_hash[ems.id] = ems.name
    end
  end

  if dialog_hash.blank?
    log(:info, "User: #{$evm.root['user'].name} has no access to Providers")
    dialog_hash[nil] = "< No Providers Found for Tenant: #{tenant.name rescue 'unknown'}, Contact Administrator >"
  else
    #$evm.object['default_value'] = dialog_hash.first
    dialog_hash[nil] = '< choose a provider >'
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
