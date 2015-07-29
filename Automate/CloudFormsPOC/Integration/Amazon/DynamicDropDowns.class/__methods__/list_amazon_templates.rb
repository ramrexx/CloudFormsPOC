# list_amazon_templates.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Build list of Amazon tempalates
#
def get_provider(provider_id=nil)
  $evm.root.attributes.detect { |k,v| provider_id = v if k.end_with?('provider_id') } rescue nil
  provider = $evm.vmdb(:ems_amazon).find_by_id(provider_id)
  $evm.log(:info, "Found provider: #{provider.name} via provider_id: #{provider.id}") if provider

  # set to true to default to the fist amazon provider
  use_default = false
  unless provider
    # default the provider to first openstack provider
    provider = $evm.vmdb(:ems_amazon).first if use_default
    $evm.log(:info, "Found amazon: #{provider.name} via default method") if provider && use_default
  end
  provider ? (return provider) : (return nil)
end

def get_provider_from_template(template_guid=nil)
  $evm.root.attributes.detect { |k,v| template_guid = v if k.end_with?('_guid') } rescue nil
  template = $evm.vmdb(:template_amazon).find_by_guid(template_guid)
  return nil unless template
  provider = $evm.vmdb(:ems_amazon).find_by_id(template.ems_id)
  $evm.log(:info, "Found provider: #{provider.name} via template.ems_id: #{template.ems_id}") if provider
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

def get_user
  user_search = $evm.root['dialog_userid'] || $evm.root['dialog_evm_owner_id']
  user = $evm.vmdb('user').find_by_id(user_search) ||
    $evm.vmdb('user').find_by_userid(user_search) ||
    $evm.root['user']
  user
end

def get_current_group_rbac_array(user, rbac_array = [])
  unless user.current_group.filters.blank?
    user.current_group.filters['managed'].flatten.each do |filter|
      next unless /(?<category>\w*)\/(?<tag>\w*)$/i =~ filter
      rbac_array << {category=>tag}
    end
  end
  $evm.log(:info, "rbac filters: #{rbac_array}")
  rbac_array
end

def template_eligible?(rbac_array, template, provider_id=nil)
  return false if template.archived || template.orphaned
  if provider_id
    return false unless template.ems_id == provider_id
  end
  rbac_array.each do |rbac_hash|
    rbac_hash.each {|category, tag| return false unless template.tagged_with?(category, tag)}
  end
  true
end


$evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}
user = get_user
rbac_array = get_current_group_rbac_array(user)

dialog_hash = {}

provider = get_provider(query_catalogitem(:src_ems_id)) || get_provider_from_template()
provider ? (provider_id = provider.id) : (provider_id = nil)

$evm.vmdb(:template_amazon).all.each do |template|
  if template_eligible?(rbac_array, template, provider_id)
    dialog_hash[template[:guid]] = "#{template.name} on #{template.ext_management_system.name}"
  end
end

if dialog_hash.blank?
  dialog_hash[''] = "< No Templates found. Contact Administrator >"
else
  dialog_hash[''] = '< choose a template >'
end

$evm.object["values"]     = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
