# list_amazon_templates.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List Amazon Template ids
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
    # get the tenant tag from the group
    # get the tenant name from the group tenant tag
    group = $evm.root['user'].current_group
    tenant = group.tags(tenant_category).first rescue nil
    log(:info, "Found tenant tag: #{tenant} via group: #{group.description}") if tenant
    tenant ? (return tenant) : (return nil)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  prov_category = 'prov_scope'
  prov_tag = 'all'

  tenant_category = $evm.object['tenant_category'] || 'tenant'
  tenant = get_tenant(tenant_category)

  dialog_hash = {}

  if tenant
    # tenant is present so we can filter templates by tag
    $evm.vmdb(:template_amazon).all.each do |t|
      log(:info, "Looking at template: #{t.name} guid: #{t.guid} ems_ref: #{t.ems_ref}")
      next if ! t.ext_management_system || t.archived
      if t.tagged_with?(tenant_category, tenant)
        dialog_hash[t.guid] = "#{t.name} on #{t.ext_management_system.name}"
      end
    end
  else
    # This means that we are going to leverage prov_category
    $evm.vmdb(:template_amazon).all.each do |t|
      log(:info, "Looking at template: #{t.name} guid: #{t.guid} ems_ref: #{t.ems_ref}")
      next if ! t.ext_management_system || t.archived
      if t.tagged_with?(prov_category, prov_tag)
        dialog_hash[t.guid] = "#{t.name} on #{t.ext_management_system.name}"
      end
    end
  end

  if dialog_hash.blank?
    if tenant
      log(:info, "User: #{$evm.root['user'].name} with Tenant tag: #{tenant} has no access to Amazon Templates")
      dialog_hash[nil] = "< No Templates Found for Tenant tag: #{tenant}, Contact Administrator >"
    else
      log(:info, "User: #{$evm.root['user'].name} with #{prov_category} tag: #{prov_tag} has no access to Amazon Templates")
      dialog_hash[nil] = "< No Templates Found for #{prov_category} tag: #{prov_tag}, Contact Administrator >"
    end
  else
    #$evm.object['default_value'] = dialog_hash.first if dialog_hash.count == 1
    dialog_hash[nil] = '< choose a template >'
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
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
