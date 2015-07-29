# list_openstack_cloudinit_templates.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: list cloud-init customization template ids that reside in the OpenStack System Image Type or
#  that contain the word 'Openstack'
#
def search_customization_templates_by_name(search_string, customization_templates = [])
  customization_templates = $evm.vmdb(:customization_template_cloud_init).all.select do |ct|
    ct.name.downcase.include?(search_string)
  end
  if customization_templates
    $evm.log(:info, "Found #{customization_templates.count} customization_templates via name: #{search_string}")
  end
  customization_templates
end

def search_customization_templates_by_image_type(search_string, customization_templates = [])
  image_type = $evm.vmdb(:pxe_image_type).all.detect do |pit|
    next unless pit.name
    pit.name.downcase.include?(search_string)
  end
  if image_type
    customization_templates = image_type.customization_templates rescue []
    $evm.log(:info, "Found #{customization_templates.count} customization_templates via image_type: #{search_string}")
  end
  customization_templates
end

def customization_template_eligible?(customization_template)
  return false unless customization_template.type == "CustomizationTemplateCloudInit"
  return false if customization_template.name.nil?
  true
end

dialog_hash = {}
customization_templates = search_customization_templates_by_image_type('openstack') ||
  search_customization_templates_by_name('openstack') || []

if customization_templates.blank?
  $evm.vmdb(:customization_template_cloud_init).all.each do |ct|
    dialog_hash[ct.id] = ct.description if customization_template_eligible?(ct)
  end
else
  customization_templates.each do |ct|
    dialog_hash[ct.id] = ct.description if customization_template_eligible?(ct)
  end
end

if dialog_hash.blank?
  dialog_hash[''] = "< No customization templates found, Contact Administrator >"
else
  #$evm.object['default_value'] = dialog_hash.first
  dialog_hash[''] = '< choose a customization template >'
end

$evm.object["values"]     = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
