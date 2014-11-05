# list_openstack_flavors.rb
#
# Description: List all OpenStack Flavors
#

openstack_hash = {}

list = $evm.vmdb(:flavor_openstack).all
for flavor in list
  $evm.log(:info, "Flavor: #{flavor.inspect}")
  openstack_hash[flavor.name] = flavor.id
end

openstack_hash[nil] = nil

$evm.object["sort_by"] = "description"
$evm.object["sort_order"] = "ascending"
$evm.object["data_type"] = "string"
$evm.object["required"] = "true"
$evm.object['values'] = openstack_hash
$evm.log(:info, "Dynamic drop down values: #{$evm.object['values']}")
