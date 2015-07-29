# list_vmware_templates.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Build Dialog of all vmware tempalate guids based on the RBAC filters applied to a users group
#
def get_user
  user_search = $evm.root['dialog_userid'] || $evm.root['dialog_evm_owner_id']
  user = $evm.vmdb('user').find_by_id(user_search) || $evm.vmdb('user').find_by_userid(user_search) ||
    $evm.root['user']
  user
end

def get_current_group_rbac_array(user, rbac_array=[])
  unless user.current_group.filters.blank?
    user.current_group.filters['managed'].flatten.each do |filter|
      next unless /(?<category>\w*)\/(?<tag>\w*)$/i =~ filter
      rbac_array << {category=>tag}
    end
  end
  $evm.log(:info, "rbac filters: #{rbac_array}")
  rbac_array
end

def template_eligible?(rbac_array, template)
  return false if template.archived || template.orphaned
  rbac_array.each do |rbac_hash|
    rbac_hash.each {|category, tag| return false unless template.tagged_with?(category, tag)}
  end
  $evm.log(:info, "template: #{template.name} is eligible")
  true
end

user = get_user
rbac_array = get_current_group_rbac_array(user)

dialog_hash = {}
$evm.vmdb(:template_vmware).all.each do |template|
  if template_eligible?(rbac_array, template)
    dialog_hash[template[:guid]] = "#{template.name} on #{template.ext_management_system.name}"
  end
end

if dialog_hash.blank?
  log(:info, "No Templates found")
  dialog_hash[''] = "< No Templates found >"
else
  dialog_hash[''] = '< choose a template >'
end

$evm.object["values"] = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
