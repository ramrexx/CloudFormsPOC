# list_amazon_providers.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List all authenticated Amazon providers
#
def dump_root_attributes
  $evm.log(:info, "Begin $evm.root.attributes")
  $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}
  $evm.log(:info, "End $evm.root.attributes")
end

def provider_eligible?(provider)
  return false unless provider.authentication_status == 'Valid'
  $evm.log(:info, "provider: #{provider.name} is eligible")
  true
end

dialog_hash = {}

$evm.vmdb(:ems_amazon).all.each { |provider|
  if provider_eligible?(provider)
    dialog_hash[provider.id] = "#{provider.provider_region}"
  end
}

if dialog_hash.blank?
  $evm.log(:info, "No Providers Found, Contact Administrator")
  dialog_hash[''] = "< No Providers Found, Contact Administrator >"
else
  #$evm.object['default_value'] = dialog_hash.first
  dialog_hash[''] = '< choose a provider >'
end

$evm.object['values'] = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
