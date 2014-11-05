
begin

  @method = "listGlanceTemplates"

  def log(level, msg)
    $evm.log(level, "#{@method} - #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_tenant
    tenant_ems_id = $evm.root['dialog_cloud_tenant']
    log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
    return tenant_ems_id if tenant_ems_id.nil?

    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
    log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
    return tenant
  end

  log(:info, "Begin Automate Method")

  dump_root
  tenant = get_tenant

  log(:info, "Found Tenant #{tenant.name rescue "admin"}")

  template_hash = {}
  template_hash[nil] = nil

  mid = $evm.root['dialog_mid']
  mid = $evm.vmdb(:ems_openstack).all.first.id if mid.blank?

  log(:info, "Working in EMS ID #{mid}")

  $evm.vmdb(:template_openstack).all.each { |template|
     log(:info, "Found Template: #{template.inspect}")
     next unless template.ems_id.to_s == mid.to_s
     template_hash[template.name] = template.ems_ref if template.cloud_tenant_id.to_s == tenant.id.to_s || template.publicly_available
  }

  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = template_hash

  log(:info, "Dropdown Values Are #{$evm.object['values'].inspect}")

  log(:info, "End Automate Method")
rescue => err
  log(:error, "#{err.class} [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
