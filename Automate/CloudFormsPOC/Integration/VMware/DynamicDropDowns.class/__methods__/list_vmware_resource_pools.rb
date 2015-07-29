# list_vmware_resource_pools.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List the resource pools associated with a provider
#
$evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" if vm.nil?

provider = vm.ext_management_system
$evm.log(:info, "Detected Provider: #{provider.name}")

pools_hash = {}

provider.resource_pools.each do |pool|
  log(:info, "Looking at resource_pool: #{pool.name} id: #{pool.id} ems_ref: #{pool.ems_ref}")
  if vm.resource_pool && vm.resource_pool.ems_ref == pool.ems_ref
    pools_hash[pool[:ems_ref]] = "<current> #{pool[:name]}"
  else
    pools_hash[pool[:ems_ref]] = pool[:name]
  end
end
pools_hash[''] = '< Choose a pool >'

$evm.object['values'] = pools_hash
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
