# list_amazon_security_groups.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: list amazon security groups
#
def get_provider(provider_id=nil)
  $evm.root.attributes.detect { |k,v| provider_id = v if k.end_with?('provider_id') } rescue nil
  provider = $evm.vmdb(:ems_amazon).find_by_id(provider_id)
  $evm.log(:info, "Found provider: #{provider.name} via root provider_id: #{provider.id}") if provider

  use_default = false
  unless provider
    provider = $evm.vmdb(:ems_amazon).first if use_default
    $evm.log(:info, "Found amazon: #{provider.name} via default method") if provider && use_default
  end
  provider ? (return provider) : (return nil)
end

def query_catalogitem(option_key, option_value=nil)
  # use this method to query a catalogitem
  # note that this only works for items not bundles since we do not know which item within a bundle(s) to query from
  service_template = $evm.root['service_template']
  unless service_template.nil?
    begin
      if service_template.service_type == 'atomic'
        $evm.log(:info, "Catalog item: #{service_template.name}")
        service_template.service_resources.each do |catalog_item|
          catalog_item_resource = catalog_item.resource
          if catalog_item_resource.respond_to?('get_option')
            option_value = catalog_item_resource.get_option(option_key)
          else
            option_value = catalog_item_resource[option_key] rescue nil
          end
          $evm.log(:info, "Found {#{option_key} => #{option_value}}") if option_value
        end
      else
        $evm.log(:info, "Catalog bundle: #{service_template.name} found, skipping query")
      end
    rescue
      return nil
    end
  end
  option_value ? (return option_value) : (return nil)
end

def get_provider_from_template(template_guid=nil)
  $evm.root.attributes.detect { |k,v| template_guid = v if k.end_with?('_guid') } rescue nil
  template = $evm.vmdb(:template_amazon).find_by_guid(template_guid)
  return nil unless template
  provider = $evm.vmdb(:ems_amazon).find_by_id(template.ems_id)
  $evm.log(:info, "Found provider: #{provider.name} via template ems_id: #{template.ems_id}") if provider
  provider
end

def securitygroup_eligible?(security_group, provider=nil)
  return false if security_group.name.nil?
  if provider
    return false unless security_group.ems_id == provider.id
  end
  true
end

dialog_hash = {}

provider = get_provider(query_catalogitem(:src_ems_id)) || get_provider_from_template()

if provider
  $evm.vmdb(:security_group_amazon).all.each do |security_group|
    next unless securitygroup_eligible?(security_group, provider)
    dialog_hash[security_group.id] = "#{security_group.name} on #{security_group.ext_management_system.name}"
  end
else
  # no provider so list everything
  $evm.vmdb(:security_group_amazon).all.each do |security_group|
    next unless securitygroup_eligible?(security_group)
    dialog_hash[security_group.id] = "#{security_group.name} on #{security_group.ext_management_system.name}"
  end
end

if dialog_hash.blank?
  $evm.log(:info, "No security groups found")
  dialog_hash[''] = "< No security groups found, Contact Administrator >"
else
  #$evm.object['default_value'] = dialog_hash.first
  dialog_hash[''] = '< choose a security groups >'
end

$evm.object["values"]     = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
